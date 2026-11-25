"""Integration tests: a real server on a real socket."""

import json
import threading
import urllib.error
import urllib.request
from datetime import date

import pytest

from lifepilot import db, web
from lifepilot.models import Budget, Transaction


@pytest.fixture
def populated_db(tmp_path):
    path = tmp_path / "web.db"
    with db.session(path) as conn:
        db.add_transactions(
            conn,
            [
                Transaction(date(2026, 10, 1), "ACME PAYROLL", 300000, category="income"),
                Transaction(date(2026, 10, 5), "Monthly Rent", -110000, category="housing"),
                Transaction(date(2026, 11, 1), "ACME PAYROLL", 320000, category="income"),
                Transaction(date(2026, 11, 3), "Monthly Rent", -115000, category="housing"),
                Transaction(date(2026, 11, 5), "TESCO 441", -8000, category="groceries"),
                Transaction(date(2026, 11, 9), "ALDI 221", -4000, category="groceries"),
                Transaction(date(2026, 11, 18), "To savings", -40000, category="transfers"),
                Transaction(
                    date(2026, 11, 20), "<script>alert('x')</script>", -1000, category="odd"
                ),
            ],
        )
        db.set_budget(conn, Budget("groceries", 10000))
        db.set_budget(conn, Budget("housing", 120000))
    return path


@pytest.fixture
def base_url(populated_db):
    server = web.make_server(port=web.free_port(), db_path=populated_db, quiet=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        host, port = server.server_address[:2]
        yield f"http://{host}:{port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def get(url, method="GET"):
    request = urllib.request.Request(url, method=method)
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status, dict(response.headers), response.read()


def test_dashboard_renders(base_url):
    status, headers, body = get(f"{base_url}/?month=2026-11")
    text = body.decode("utf-8")
    assert status == 200
    assert headers["Content-Type"] == "text/html; charset=utf-8"
    assert "November 2026" in text
    assert "1,920.00" in text  # net: 3,200.00 income - 1,280.00 expenses, transfer excluded
    assert "hero-value" in text


def test_security_headers_are_set(base_url):
    _, headers, _ = get(f"{base_url}/")
    csp = headers["Content-Security-Policy"]
    assert "default-src 'none'" in csp
    assert "script-src 'self'" in csp  # no inline script
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["Cache-Control"] == "no-store"


def test_untrusted_descriptions_are_escaped(base_url):
    _, _, body = get(f"{base_url}/transactions?month=2026-11")
    text = body.decode("utf-8")
    assert "<script>alert" not in text
    assert "&lt;script&gt;" in text


def test_static_assets(base_url):
    status, headers, body = get(f"{base_url}/static/app.css")
    assert status == 200
    assert headers["Content-Type"] == "text/css; charset=utf-8"
    assert b"--series-1" in body

    status, headers, body = get(f"{base_url}/static/app.js")
    assert status == 200
    assert headers["Content-Type"] == "text/javascript; charset=utf-8"
    assert b"textContent" in body  # tooltips never use innerHTML


def test_api_report(base_url):
    _, headers, body = get(f"{base_url}/api/report?month=2026-11")
    assert headers["Content-Type"] == "application/json; charset=utf-8"
    payload = json.loads(body)
    assert payload["month"] == "2026-11"
    assert payload["summary"]["income_cents"] == 320000
    assert payload["summary"]["net_cents"] == 192000
    categories = {c["category"]: c["total_cents"] for c in payload["categories"]}
    assert categories["housing"] == 115000
    assert "transfers" not in categories
    budgets = {b["category"]: b for b in payload["budgets"]}
    assert budgets["groceries"]["over_budget"] is True


def test_month_defaults_to_newest_with_data(base_url):
    _, _, body = get(f"{base_url}/api/report")
    assert json.loads(body)["month"] == "2026-11"


def test_invalid_month_falls_back_instead_of_failing(base_url):
    status, _, body = get(f"{base_url}/api/report?month=not-a-month")
    assert status == 200
    assert json.loads(body)["month"] == "2026-11"


def test_month_without_data_still_renders(base_url):
    status, _, body = get(f"{base_url}/?month=2020-01")
    assert status == 200
    text = body.decode("utf-8")
    assert "January 2020" in text
    assert "No spending recorded" in text


def test_transactions_filters(base_url):
    _, _, body = get(f"{base_url}/transactions?month=2026-11&category=groceries")
    text = body.decode("utf-8")
    assert "TESCO 441" in text
    assert "Monthly Rent" not in text

    _, _, body = get(f"{base_url}/transactions?month=2026-11&q=ALDI")
    text = body.decode("utf-8")
    assert "ALDI 221" in text
    assert "TESCO 441" not in text


def test_trailing_slash_is_accepted(base_url):
    status, _, _ = get(f"{base_url}/transactions/?month=2026-11")
    assert status == 200


def test_head_returns_headers_without_a_body(base_url):
    status, headers, body = get(f"{base_url}/", method="HEAD")
    assert status == 200
    assert int(headers["Content-Length"]) > 0
    assert body == b""


def test_unknown_path_is_a_404_page(base_url):
    with pytest.raises(urllib.error.HTTPError) as caught:
        get(f"{base_url}/nope")
    assert caught.value.code == 404
    assert b"No page at" in caught.value.read()


def test_serve_refuses_when_the_database_is_missing(tmp_path, capsys):
    assert web.serve(db_path=tmp_path / "nothing.db") == 2
    assert "Run `lifepilot init` first" in capsys.readouterr().err


def test_serve_reports_an_unusable_port(populated_db, capsys):
    blocker = web.make_server(port=web.free_port(), db_path=populated_db, quiet=True)
    try:
        port = blocker.server_address[1]
        assert web.serve(port=port, db_path=populated_db) == 2
        assert "Could not bind" in capsys.readouterr().err
    finally:
        blocker.server_close()


def test_resolve_month_offers_every_month_with_data(populated_db):
    with db.session(populated_db) as conn:
        month, months = web.resolve_month(conn, None)
        assert month == "2026-11"
        assert months == ["2026-11", "2026-10"]

        month, months = web.resolve_month(conn, "2024-03")
        assert month == "2024-03"
        assert "2024-03" in months  # the requested month is never silently dropped


def test_resolve_month_on_an_empty_database(tmp_path):
    with db.session(tmp_path / "empty.db") as conn:
        month, months = web.resolve_month(conn, None)
        assert month in months
        assert len(months) == 1
