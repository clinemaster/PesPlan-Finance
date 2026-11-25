"""Aggregate reports over stored transactions.

Stored amounts are signed (expenses negative). Reports convert expense figures
to positive magnitudes, because "spent 420.00" reads better than "spent -420.00";
`net_cents` keeps its sign so a deficit shows as negative.
"""

from __future__ import annotations

import calendar
import sqlite3
from dataclasses import dataclass
from datetime import date as Date


def month_bounds(month: str) -> tuple[str, str]:
    """Inclusive ISO date bounds for a 'YYYY-MM' month key."""
    try:
        year_s, month_s = month.split("-")
        year, mon = int(year_s), int(month_s)
        if not 1 <= mon <= 12:
            raise ValueError
    except ValueError:
        raise ValueError(f"expected a month as YYYY-MM, got {month!r}") from None
    last_day = calendar.monthrange(year, mon)[1]
    return f"{year:04d}-{mon:02d}-01", f"{year:04d}-{mon:02d}-{last_day:02d}"


def current_month() -> str:
    return Date.today().strftime("%Y-%m")


@dataclass(slots=True)
class Summary:
    income_cents: int = 0
    expense_cents: int = 0  # positive magnitude
    count: int = 0

    @property
    def net_cents(self) -> int:
        return self.income_cents - self.expense_cents

    @property
    def savings_rate(self) -> float:
        """Share of income not spent, 0.0 when there is no income."""
        if self.income_cents <= 0:
            return 0.0
        return self.net_cents / self.income_cents


@dataclass(slots=True)
class CategoryTotal:
    category: str
    total_cents: int
    count: int
    share: float = 0.0  # fraction of the report's grand total


@dataclass(slots=True)
class BudgetLine:
    category: str
    budget_cents: int
    spent_cents: int

    @property
    def remaining_cents(self) -> int:
        return self.budget_cents - self.spent_cents

    @property
    def used_share(self) -> float:
        if self.budget_cents <= 0:
            return 0.0
        return self.spent_cents / self.budget_cents

    @property
    def over_budget(self) -> bool:
        return self.spent_cents > self.budget_cents


def _range_clause(start: str | None, end: str | None) -> tuple[str, list[object]]:
    sql, params = "", []
    if start:
        sql += " AND date >= ?"
        params.append(start)
    if end:
        sql += " AND date <= ?"
        params.append(end)
    return sql, params


def summary(
    conn: sqlite3.Connection,
    *,
    start: str | None = None,
    end: str | None = None,
    exclude_categories: tuple[str, ...] = ("transfers",),
) -> Summary:
    """Income, expenses and count over a date range.

    Transfers are excluded by default: money moved between your own accounts is
    not income or spending, and counting it double-skews every total.
    """
    clause, params = _range_clause(start, end)
    if exclude_categories:
        placeholders = ",".join("?" for _ in exclude_categories)
        clause += f" AND category NOT IN ({placeholders})"
        params.extend(exclude_categories)

    row = conn.execute(
        f"""SELECT
                COALESCE(SUM(CASE WHEN amount_cents > 0 THEN amount_cents END), 0)  AS income,
                COALESCE(SUM(CASE WHEN amount_cents < 0 THEN -amount_cents END), 0) AS expense,
                COUNT(*)                                                            AS n
            FROM transactions WHERE 1=1{clause}""",
        params,
    ).fetchone()
    return Summary(income_cents=row["income"], expense_cents=row["expense"], count=row["n"])


def by_category(
    conn: sqlite3.Connection,
    *,
    start: str | None = None,
    end: str | None = None,
    expenses_only: bool = True,
    exclude_categories: tuple[str, ...] = ("transfers",),
) -> list[CategoryTotal]:
    """Totals per category, largest first."""
    clause, params = _range_clause(start, end)
    if expenses_only:
        clause += " AND amount_cents < 0"
    if exclude_categories:
        placeholders = ",".join("?" for _ in exclude_categories)
        clause += f" AND category NOT IN ({placeholders})"
        params.extend(exclude_categories)

    rows = conn.execute(
        f"""SELECT category, SUM(amount_cents) AS total, COUNT(*) AS n
            FROM transactions WHERE 1=1{clause}
            GROUP BY category""",
        params,
    ).fetchall()

    totals = [
        CategoryTotal(
            category=r["category"],
            total_cents=-r["total"] if expenses_only else r["total"],
            count=r["n"],
        )
        for r in rows
    ]
    grand = sum(abs(t.total_cents) for t in totals)
    if grand:
        for t in totals:
            t.share = abs(t.total_cents) / grand
    totals.sort(key=lambda t: abs(t.total_cents), reverse=True)
    return totals


def monthly_trend(
    conn: sqlite3.Connection,
    *,
    months: int = 6,
    exclude_categories: tuple[str, ...] = ("transfers",),
) -> list[tuple[str, Summary]]:
    """Per-month summaries for the most recent `months` with activity, oldest first."""
    clause, params = "", []
    if exclude_categories:
        placeholders = ",".join("?" for _ in exclude_categories)
        clause = f" AND category NOT IN ({placeholders})"
        params.extend(exclude_categories)

    rows = conn.execute(
        f"""SELECT substr(date, 1, 7) AS month,
                   COALESCE(SUM(CASE WHEN amount_cents > 0 THEN amount_cents END), 0)  AS income,
                   COALESCE(SUM(CASE WHEN amount_cents < 0 THEN -amount_cents END), 0) AS expense,
                   COUNT(*) AS n
            FROM transactions WHERE 1=1{clause}
            GROUP BY month
            ORDER BY month DESC
            LIMIT ?""",
        [*params, months],
    ).fetchall()

    trend = [
        (r["month"], Summary(income_cents=r["income"], expense_cents=r["expense"], count=r["n"]))
        for r in rows
    ]
    trend.reverse()
    return trend


def budget_report(conn: sqlite3.Connection, month: str) -> list[BudgetLine]:
    """Budget vs actual for one month, worst overrun first.

    Categories with a budget but no spend are included (spent 0); categories
    with spend but no budget are not — set a budget to track them.
    """
    start, end = month_bounds(month)
    rows = conn.execute(
        """SELECT b.category,
                  b.monthly_cents AS budget,
                  COALESCE((
                      SELECT SUM(-t.amount_cents) FROM transactions t
                      WHERE t.category = b.category
                        AND t.amount_cents < 0
                        AND t.date BETWEEN ? AND ?
                  ), 0) AS spent
           FROM budgets b
           ORDER BY b.category""",
        (start, end),
    ).fetchall()

    lines = [
        BudgetLine(category=r["category"], budget_cents=r["budget"], spent_cents=r["spent"])
        for r in rows
    ]
    lines.sort(key=lambda line: line.used_share, reverse=True)
    return lines


# --- yearly ---------------------------------------------------------------


def year_bounds(year: int) -> tuple[str, str]:
    """Inclusive ISO date bounds for a calendar year."""
    year = int(year)
    if not 1 <= year <= 9999:
        raise ValueError(f"year out of range: {year}")
    return f"{year:04d}-01-01", f"{year:04d}-12-31"


def current_year() -> int:
    return Date.today().year


def available_years(conn: sqlite3.Connection) -> list[int]:
    """Years that have transactions, newest first."""
    rows = conn.execute(
        "SELECT DISTINCT substr(date, 1, 4) AS year FROM transactions ORDER BY year DESC"
    ).fetchall()
    return [int(row["year"]) for row in rows]


def month_series(
    conn: sqlite3.Connection,
    year: int,
    *,
    exclude_categories: tuple[str, ...] = ("transfers",),
) -> list[Summary | None]:
    """Twelve slots, January to December, for one calendar year.

    A month with no transactions is None rather than a zeroed Summary: plotting
    an untouched month as 0.00 would claim you spent nothing, which is a
    different statement from having no records - and it would drag a trend line
    down to the axis for every month still in the future.
    """
    start, end = year_bounds(year)
    clause, params = "", [start, end]
    if exclude_categories:
        placeholders = ",".join("?" for _ in exclude_categories)
        clause = f" AND category NOT IN ({placeholders})"
        params.extend(exclude_categories)

    rows = conn.execute(
        f"""SELECT substr(date, 1, 7) AS month,
                   COALESCE(SUM(CASE WHEN amount_cents > 0 THEN amount_cents END), 0)  AS income,
                   COALESCE(SUM(CASE WHEN amount_cents < 0 THEN -amount_cents END), 0) AS expense,
                   COUNT(*) AS n
            FROM transactions
            WHERE date BETWEEN ? AND ?{clause}
            GROUP BY month""",
        params,
    ).fetchall()

    found = {
        row["month"]: Summary(
            income_cents=row["income"], expense_cents=row["expense"], count=row["n"]
        )
        for row in rows
    }
    return [found.get(f"{int(year):04d}-{month:02d}") for month in range(1, 13)]


def yearly_summaries(
    conn: sqlite3.Connection,
    *,
    exclude_categories: tuple[str, ...] = ("transfers",),
) -> list[tuple[int, Summary]]:
    """One summary per year with activity, oldest first."""
    clause, params = "", []
    if exclude_categories:
        placeholders = ",".join("?" for _ in exclude_categories)
        clause = f" WHERE category NOT IN ({placeholders})"
        params.extend(exclude_categories)

    rows = conn.execute(
        f"""SELECT substr(date, 1, 4) AS year,
                   COALESCE(SUM(CASE WHEN amount_cents > 0 THEN amount_cents END), 0)  AS income,
                   COALESCE(SUM(CASE WHEN amount_cents < 0 THEN -amount_cents END), 0) AS expense,
                   COUNT(*) AS n
            FROM transactions{clause}
            GROUP BY year
            ORDER BY year""",
        params,
    ).fetchall()
    return [
        (
            int(row["year"]),
            Summary(income_cents=row["income"], expense_cents=row["expense"], count=row["n"]),
        )
        for row in rows
    ]


def month_average(series: list[Summary | None]) -> int:
    """Mean monthly spend across the months that have records."""
    spends = [s.expense_cents for s in series if s is not None]
    return round(sum(spends) / len(spends)) if spends else 0
