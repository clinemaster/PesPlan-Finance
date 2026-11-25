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


# --- yearly ---------------------------------------------------------------


@pytest.fixture
def two_years(tmp_path):
    """Two full-ish years, so year-over-year has something to compare."""
    path = tmp_path / "years.db"
    rows = []
    for year, pay, rent in ((2025, 300000, -100000), (2026, 320000, -110000)):
        for month in range(1, 13 if year == 2025 else 7):
            rows.append(
                Transaction(date(year, month, 1), "ACME PAYROLL", pay, category="income")
            )
            rows.append(Transaction(date(year, month, 3), "Rent", rent, category="housing"))
            rows.append(
                Transaction(date(year, month, 7), "TESCO", -8000 - month * 100,
                            category="groceries")
            )
    with db.session(path) as conn:
        db.add_transactions(conn, rows)
    return path


@pytest.fixture
def years_url(two_years):
    server = web.make_server(port=web.free_port(), db_path=two_years, quiet=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        host, port = server.server_address[:2]
        yield f"http://{host}:{port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def test_year_page_renders_both_charts(years_url):
    status, _, body = get(f"{years_url}/year?year=2026")
    text = body.decode("utf-8")
    assert status == 200
    assert "Spent in 2026" in text
    assert 'class="col series-2"' in text          # monthly spending columns
    assert 'class="line series-2"' in text         # this year's line
    assert 'class="line series-context"' in text   # last year's line
    assert text.count("data-cx=") == 12            # a crosshair position per month


def test_year_page_defaults_to_the_newest_year(years_url):
    _, _, body = get(f"{years_url}/year")
    assert "Spent in 2026" in body.decode("utf-8")


def test_year_page_handles_a_year_without_data(years_url):
    status, _, body = get(f"{years_url}/year?year=2019")
    text = body.decode("utf-8")
    assert status == 200
    assert "No transactions recorded in 2019" in text


def test_year_page_ignores_a_junk_year(years_url):
    status, _, body = get(f"{years_url}/year?year=abc")
    assert status == 200
    assert "Spent in 2026" in body.decode("utf-8")


def test_api_year(years_url):
    _, headers, body = get(f"{years_url}/api/year?year=2026")
    assert headers["Content-Type"] == "application/json; charset=utf-8"
    payload = json.loads(body)
    assert payload["year"] == 2026
    # 2026 runs January to June in the fixture; the rest are nulls, not zeros.
    assert sum(1 for m in payload["months"] if m) == 6
    assert payload["months"][6] is None
    assert payload["previous_year"]["year"] == 2025
    assert sum(1 for m in payload["previous_year"]["months"] if m) == 12
    assert payload["average_monthly_spend_cents"] > 0
    assert [y["year"] for y in payload["years"]] == [2025, 2026]


def test_api_year_monthly_figures(years_url):
    _, _, body = get(f"{years_url}/api/year?year=2026")
    january = json.loads(body)["months"][0]
    assert january["income_cents"] == 320000
    assert january["expense_cents"] == 110000 + 8100
    assert january["net_cents"] == 320000 - 118100


def test_resolve_year(two_years):
    with db.session(two_years) as conn:
        assert web.resolve_year(conn, None) == (2026, [2026, 2025])
        assert web.resolve_year(conn, "2025")[0] == 2025
        year, years = web.resolve_year(conn, "2019")
        assert year == 2019 and 2019 in years


def test_resolve_year_on_an_empty_database(tmp_path):
    with db.session(tmp_path / "empty.db") as conn:
        year, years = web.resolve_year(conn, None)
        assert year in years
