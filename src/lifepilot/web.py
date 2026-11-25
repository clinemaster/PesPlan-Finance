"""A local web UI for the reports.

Deliberately built on `http.server` rather than a framework: the project has no
runtime dependencies, and a single-user dashboard reading a local SQLite file
does not need more than this.

The server is read-only - it renders reports and never writes to the database.
It binds to loopback by default, because the pages show your finances and there
is no authentication.
"""

from __future__ import annotations

import json
import os
import socket
import sqlite3
import sys
import threading
import webbrowser
from functools import partial
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from . import db, render, reports
from .money import format_money

STATIC_DIR = Path(__file__).parent / "static"

STATIC_FILES = {
    "/static/app.css": "text/css; charset=utf-8",
    "/static/app.js": "text/javascript; charset=utf-8",
}

# Nothing is loaded from the network, so everything but same-origin is denied.
# 'unsafe-inline' is allowed for styles only: bar and meter widths are rendered
# as style attributes. Scripts stay strict - no inline script anywhere.
CONTENT_SECURITY_POLICY = (
    "default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self'; "
    "img-src 'self' data:; form-action 'self'; base-uri 'none'"
)

TREND_MONTHS = 12
RECENT_LIMIT = 10
LOOPBACK = {"127.0.0.1", "::1", "localhost"}


# --- data gathering -------------------------------------------------------


def available_months(conn: sqlite3.Connection) -> list[str]:
    """Months that actually have transactions, newest first."""
    rows = conn.execute(
        "SELECT DISTINCT substr(date, 1, 7) AS month FROM transactions ORDER BY month DESC"
    ).fetchall()
    return [row["month"] for row in rows]


def resolve_month(conn: sqlite3.Connection, requested: str | None) -> tuple[str, list[str]]:
    """Pick the month to show, and the list offered in the filter.

    A requested month is honoured even when empty, so the picker never silently
    jumps somewhere else; otherwise the newest month with data wins.
    """
    months = available_months(conn)
    current = render.today_month()
    if requested:
        try:
            reports.month_bounds(requested)
        except ValueError:
            requested = None
    month = requested or (months[0] if months else current)
    if month not in months:
        months = sorted({*months, month}, reverse=True)
    return month, months


def dashboard_html(conn: sqlite3.Connection, requested: str | None) -> str:
    month, months = resolve_month(conn, requested)
    start, end = reports.month_bounds(month)

    previous_key = render.previous_month(month)
    prev_start, prev_end = reports.month_bounds(previous_key)
    previous = reports.summary(conn, start=prev_start, end=prev_end)

    return render.dashboard(
        month=month,
        months=months,
        summary=reports.summary(conn, start=start, end=end),
        previous=previous if previous.count else None,
        categories=reports.by_category(conn, start=start, end=end),
        trend=reports.monthly_trend(conn, months=TREND_MONTHS),
        budgets=reports.budget_report(conn, month),
        recent=db.list_transactions(conn, start=start, end=end, limit=RECENT_LIMIT),
    )


def transactions_html(
    conn: sqlite3.Connection, requested: str | None, category: str, query: str
) -> str:
    month, months = resolve_month(conn, requested)
    start, end = reports.month_bounds(month)
    rows = conn.execute("SELECT DISTINCT category FROM transactions ORDER BY category").fetchall()
    return render.transactions_page(
        month=month,
        months=months,
        txs=db.list_transactions(
            conn,
            start=start,
            end=end,
            category=category or None,
            search=query or None,
            limit=500,
        ),
        categories=[row["category"] for row in rows],
        category=category,
        query=query,
    )


def resolve_year(conn: sqlite3.Connection, requested: str | None) -> tuple[int, list[int]]:
    """Pick the year to show, and the list offered in the filter."""
    years = reports.available_years(conn)
    if requested:
        try:
            year = int(requested)
            reports.year_bounds(year)
        except ValueError:
            year = None
    else:
        year = None
    if year is None:
        year = years[0] if years else reports.current_year()
    if year not in years:
        years = sorted({*years, year}, reverse=True)
    return year, years


def year_html(conn: sqlite3.Connection, requested: str | None) -> str:
    year, years = resolve_year(conn, requested)
    start, end = reports.year_bounds(year)
    series = reports.month_series(conn, year)
    totals = reports.yearly_summaries(conn)
    by_year = dict(totals)
    return render.year_page(
        year=year,
        years=years,
        summary=reports.summary(conn, start=start, end=end),
        previous=by_year.get(year - 1),
        series=series,
        previous_series=reports.month_series(conn, year - 1),
        average=reports.month_average(series),
        categories=reports.by_category(conn, start=start, end=end),
        totals=totals,
    )


def year_json(conn: sqlite3.Connection, requested: str | None) -> dict:
    """Yearly trends as data: monthly series, the prior year, and year totals."""
    year, _ = resolve_year(conn, requested)
    start, end = reports.year_bounds(year)
    series = reports.month_series(conn, year)
    previous = reports.month_series(conn, year - 1)
    summary = reports.summary(conn, start=start, end=end)

    def months(data):
        return [
            None
            if s is None
            else {
                "month": f"{year:04d}-{i + 1:02d}",
                "income_cents": s.income_cents,
                "expense_cents": s.expense_cents,
                "net_cents": s.net_cents,
                "transactions": s.count,
            }
            for i, s in enumerate(data)
        ]

    return {
        "year": year,
        "summary": {
            "income_cents": summary.income_cents,
            "expense_cents": summary.expense_cents,
            "net_cents": summary.net_cents,
            "savings_rate": round(summary.savings_rate, 4),
            "transactions": summary.count,
        },
        "average_monthly_spend_cents": reports.month_average(series),
        "months": months(series),
        "previous_year": {"year": year - 1, "months": months(previous)},
        "categories": [
            {"category": t.category, "total_cents": t.total_cents, "count": t.count,
             "share": round(t.share, 4)}
            for t in reports.by_category(conn, start=start, end=end)
        ],
        "years": [
            {"year": y, "income_cents": v.income_cents, "expense_cents": v.expense_cents,
             "net_cents": v.net_cents, "transactions": v.count}
            for y, v in reports.yearly_summaries(conn)
        ],
    }


def report_json(conn: sqlite3.Connection, requested: str | None) -> dict:
    """The same numbers the dashboard shows, for scripting against."""
    month, _ = resolve_month(conn, requested)
    start, end = reports.month_bounds(month)
    summary = reports.summary(conn, start=start, end=end)
    return {
        "month": month,
        "summary": {
            "income": format_money(summary.income_cents),
            "expenses": format_money(summary.expense_cents),
            "net": format_money(summary.net_cents),
            "income_cents": summary.income_cents,
            "expense_cents": summary.expense_cents,
            "net_cents": summary.net_cents,
            "savings_rate": round(summary.savings_rate, 4),
            "transactions": summary.count,
        },
        "categories": [
            {"category": t.category, "total_cents": t.total_cents, "count": t.count,
             "share": round(t.share, 4)}
            for t in reports.by_category(conn, start=start, end=end)
        ],
        "trend": [
            {"month": m, "income_cents": s.income_cents, "expense_cents": s.expense_cents,
             "net_cents": s.net_cents}
            for m, s in reports.monthly_trend(conn, months=TREND_MONTHS)
        ],
        "budgets": [
            {"category": line.category, "budget_cents": line.budget_cents,
             "spent_cents": line.spent_cents, "remaining_cents": line.remaining_cents,
             "used_share": round(line.used_share, 4), "over_budget": line.over_budget}
            for line in reports.budget_report(conn, month)
        ],
    }


# --- request handling -----------------------------------------------------


class Handler(BaseHTTPRequestHandler):
    """Routes the handful of read-only endpoints the dashboard needs."""

    server_version = "LifePilot"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, db_path: str | os.PathLike[str] | None = None, quiet: bool = False):
        self.db_path = db_path
        self.quiet = quiet
        super().__init__(*args)

    # BaseHTTPRequestHandler logs every hit to stderr; keep the console usable.
    def log_message(self, format: str, *args) -> None:  # noqa: A002 - base class name
        if not self.quiet:
            sys.stderr.write(f"{self.address_string()} - {format % args}\n")

    def do_HEAD(self) -> None:
        self._handle(body_wanted=False)

    def do_GET(self) -> None:
        self._handle(body_wanted=True)

    def _handle(self, *, body_wanted: bool) -> None:
        parsed = urlparse(self.path)
        route = parsed.path.rstrip("/") or "/"
        params = parse_qs(parsed.query)

        def first(name: str) -> str:
            values = params.get(name) or [""]
            return values[0].strip()

        try:
            if route in STATIC_FILES:
                self._serve_static(route, body_wanted=body_wanted)
                return
            if route == "/favicon.ico":
                self._respond(HTTPStatus.NO_CONTENT, b"", "image/x-icon", body_wanted=False)
                return

            if route == "/":
                with db.session(self.db_path) as conn:
                    html = dashboard_html(conn, first("month") or None)
                self._respond_html(html, body_wanted=body_wanted)
                return

            if route == "/year":
                with db.session(self.db_path) as conn:
                    html = year_html(conn, first("year") or None)
                self._respond_html(html, body_wanted=body_wanted)
                return

            if route == "/transactions":
                with db.session(self.db_path) as conn:
                    html = transactions_html(
                        conn, first("month") or None, first("category"), first("q")
                    )
                self._respond_html(html, body_wanted=body_wanted)
                return

            if route == "/api/year":
                with db.session(self.db_path) as conn:
                    payload = year_json(conn, first("year") or None)
                body = json.dumps(payload, indent=2).encode("utf-8")
                self._respond(
                    HTTPStatus.OK, body, "application/json; charset=utf-8",
                    body_wanted=body_wanted,
                )
                return

            if route == "/api/report":
                with db.session(self.db_path) as conn:
                    payload = report_json(conn, first("month") or None)
                body = json.dumps(payload, indent=2).encode("utf-8")
                self._respond(
                    HTTPStatus.OK, body, "application/json; charset=utf-8",
                    body_wanted=body_wanted,
                )
                return

            self._respond_html(
                render.error_page(404, f"No page at {parsed.path}"),
                status=HTTPStatus.NOT_FOUND,
                body_wanted=body_wanted,
            )
        except (sqlite3.Error, OSError, ValueError) as exc:
            self.log_message("error serving %s: %s", self.path, exc)
            self._respond_html(
                render.error_page(500, f"Could not render this page: {exc}"),
                status=HTTPStatus.INTERNAL_SERVER_ERROR,
                body_wanted=body_wanted,
            )

    def _serve_static(self, route: str, *, body_wanted: bool) -> None:
        # Routes are matched against a fixed dict, so the path never reaches
        # the filesystem untrusted.
        path = STATIC_DIR / Path(route).name
        try:
            body = path.read_bytes()
        except OSError:
            self._respond_html(
                render.error_page(404, "Missing static asset"),
                status=HTTPStatus.NOT_FOUND,
                body_wanted=body_wanted,
            )
            return
        self._respond(
            HTTPStatus.OK, body, STATIC_FILES[route], body_wanted=body_wanted,
            cache="public, max-age=300",
        )

    def _respond_html(
        self, html: str, *, status: HTTPStatus = HTTPStatus.OK, body_wanted: bool = True
    ) -> None:
        self._respond(
            status, html.encode("utf-8"), "text/html; charset=utf-8", body_wanted=body_wanted
        )

    def _respond(
        self,
        status: HTTPStatus,
        body: bytes,
        content_type: str,
        *,
        body_wanted: bool = True,
        cache: str = "no-store",
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self.send_header("Content-Security-Policy", CONTENT_SECURITY_POLICY)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        if body_wanted and body:
            self.wfile.write(body)


# --- server ---------------------------------------------------------------


class Server(ThreadingHTTPServer):
    """Threading HTTP server that refuses to share its port.

    `HTTPServer` sets `allow_reuse_address`, which on Windows lets a second
    process bind a port that is already being listened on - two servers then
    split the incoming connections instead of the second one reporting the
    conflict. Windows' own answer is SO_EXCLUSIVEADDRUSE. On POSIX, where
    SO_REUSEADDR does not permit two listeners, it stays on so a restart
    straight after Ctrl+C is not blocked by TIME_WAIT.
    """

    _exclusive = hasattr(socket, "SO_EXCLUSIVEADDRUSE")
    allow_reuse_address = not _exclusive
    daemon_threads = True

    def server_bind(self) -> None:
        if self._exclusive:
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


def make_server(
    *,
    host: str = "127.0.0.1",
    port: int = 8765,
    db_path: str | os.PathLike[str] | None = None,
    quiet: bool = False,
) -> Server:
    handler = partial(Handler, db_path=db_path, quiet=quiet)
    return Server((host, port), handler)


def serve(
    *,
    host: str = "127.0.0.1",
    port: int = 8765,
    db_path: str | os.PathLike[str] | None = None,
    open_browser: bool = False,
) -> int:
    """Run the dashboard until interrupted."""
    resolved = db.resolve_db_path(db_path)
    if not Path(resolved).exists():
        print(f"No database at {resolved}. Run `lifepilot init` first.", file=sys.stderr)
        return 2

    try:
        server = make_server(host=host, port=port, db_path=db_path)
    except OSError as exc:
        print(f"Could not bind {host}:{port} ({exc}).", file=sys.stderr)
        return 2

    bound_host, bound_port = server.server_address[:2]
    display_host = "127.0.0.1" if bound_host in ("0.0.0.0", "::") else bound_host
    url = f"http://{display_host}:{bound_port}/"

    print(f"Serving {resolved} at {url}")
    if host not in LOOPBACK:
        print(
            f"warning: bound to {host}, so anyone who can reach this machine can read "
            "your finances - there is no authentication.",
            file=sys.stderr,
        )
    print("Press Ctrl+C to stop.")

    if open_browser:
        threading.Timer(0.3, webbrowser.open, args=(url,)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


def free_port() -> int:
    """An unused port, for tests and for --port 0."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]
