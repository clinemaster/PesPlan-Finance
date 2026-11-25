from datetime import date

import pytest

from lifepilot import db, reports
from lifepilot.models import Budget, Transaction


@pytest.fixture
def populated(conn):
    db.add_transactions(
        conn,
        [
            Transaction(date(2026, 10, 1), "Payroll", 300000, category="income"),
            Transaction(date(2026, 10, 5), "Rent", -110000, category="housing"),
            Transaction(date(2026, 11, 1), "Payroll", 320000, category="income"),
            Transaction(date(2026, 11, 3), "Rent", -115000, category="housing"),
            Transaction(date(2026, 11, 5), "Tesco", -8000, category="groceries"),
            Transaction(date(2026, 11, 9), "Aldi", -4000, category="groceries"),
            Transaction(date(2026, 11, 18), "To savings", -40000, category="transfers"),
        ],
    )
    return conn


def test_month_bounds():
    assert reports.month_bounds("2026-11") == ("2026-11-01", "2026-11-30")
    assert reports.month_bounds("2024-02") == ("2024-02-01", "2024-02-29")
    assert reports.month_bounds("2026-12") == ("2026-12-01", "2026-12-31")


@pytest.mark.parametrize("bad", ["2026", "2026-13", "nov-2026", ""])
def test_month_bounds_rejects_junk(bad):
    with pytest.raises(ValueError):
        reports.month_bounds(bad)


def test_summary_excludes_transfers(populated):
    start, end = reports.month_bounds("2026-11")
    s = reports.summary(populated, start=start, end=end)
    assert s.income_cents == 320000
    assert s.expense_cents == 127000  # rent + both grocery runs, no transfer
    assert s.net_cents == 193000
    assert s.count == 4


def test_summary_savings_rate(populated):
    start, end = reports.month_bounds("2026-11")
    s = reports.summary(populated, start=start, end=end)
    assert s.savings_rate == pytest.approx(193000 / 320000)


def test_summary_with_no_income_has_zero_rate(conn):
    db.add_transaction(conn, Transaction(date(2026, 11, 1), "Coffee", -500))
    assert reports.summary(conn).savings_rate == 0.0


def test_summary_of_empty_db(conn):
    s = reports.summary(conn)
    assert (s.income_cents, s.expense_cents, s.net_cents, s.count) == (0, 0, 0, 0)


def test_by_category_sorted_with_shares(populated):
    start, end = reports.month_bounds("2026-11")
    totals = reports.by_category(populated, start=start, end=end)
    assert [t.category for t in totals] == ["housing", "groceries"]
    assert totals[0].total_cents == 115000  # positive magnitude
    assert totals[1].count == 2
    assert sum(t.share for t in totals) == pytest.approx(1.0)


def test_by_category_income_mode(populated):
    totals = reports.by_category(populated, expenses_only=False)
    assert [t.category for t in totals][0] == "income"
    assert totals[0].total_cents == 620000


def test_monthly_trend_is_oldest_first(populated):
    trend = reports.monthly_trend(populated, months=6)
    assert [month for month, _ in trend] == ["2026-10", "2026-11"]
    assert trend[0][1].expense_cents == 110000


def test_monthly_trend_respects_limit(populated):
    trend = reports.monthly_trend(populated, months=1)
    assert [month for month, _ in trend] == ["2026-11"]


def test_budget_report(populated):
    db.set_budget(populated, Budget("groceries", 10000))
    db.set_budget(populated, Budget("housing", 120000))
    db.set_budget(populated, Budget("travel", 20000))

    lines = {line.category: line for line in reports.budget_report(populated, "2026-11")}

    assert lines["groceries"].spent_cents == 12000
    assert lines["groceries"].over_budget
    assert lines["groceries"].remaining_cents == -2000

    assert lines["housing"].spent_cents == 115000
    assert not lines["housing"].over_budget
    assert lines["housing"].used_share == pytest.approx(115000 / 120000)

    # Budgeted but untouched this month.
    assert lines["travel"].spent_cents == 0


def test_budget_report_worst_overrun_first(populated):
    db.set_budget(populated, Budget("housing", 120000))
    db.set_budget(populated, Budget("groceries", 10000))
    ordered = [line.category for line in reports.budget_report(populated, "2026-11")]
    assert ordered[0] == "groceries"


def test_budget_report_ignores_other_months(populated):
    db.set_budget(populated, Budget("housing", 120000))
    lines = reports.budget_report(populated, "2026-10")
    assert lines[0].spent_cents == 110000
