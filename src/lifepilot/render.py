"""HTML rendering for the web UI.

Pure presentation: every function here takes already-computed report objects and
returns markup, so it can be tested without a database or a server.

Charts are server-rendered (CSS bars and inline SVG) rather than drawn by a
charting library, which keeps the project dependency-free and means the page
loads nothing from the network - appropriate for financial data.

Chart conventions follow one deliberate scheme:
  * the category breakdown is a single series, so every bar is one color -
    coloring each bar by its own size would double-encode bar length as hue;
  * the trend chart has two series and therefore a legend, plus direct labels
    on the most recent pair;
  * budget meters use the reserved status colors and always pair them with an
    icon and a text label, so state never rests on color alone;
  * every chart has a table-view twin, so no value is reachable only by hover.
"""

from __future__ import annotations

import html
import math
from datetime import date as Date

from .models import Transaction
from .money import format_money
from .reports import BudgetLine, CategoryTotal, Summary

MONTH_NAMES = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)


def esc(value: object) -> str:
    """Escape untrusted text. Descriptions and categories come from CSV files."""
    return html.escape(str(value), quote=True)


def month_label(month: str) -> str:
    """'2026-11' -> 'November 2026'."""
    try:
        year, mon = month.split("-")
        return f"{MONTH_NAMES[int(mon) - 1]} {year}"
    except (ValueError, IndexError):
        return month


def previous_month(month: str) -> str:
    year, mon = (int(part) for part in month.split("-"))
    return f"{year - 1:04d}-12" if mon == 1 else f"{year:04d}-{mon - 1:02d}"


def _axis_label(cents: int) -> str:
    """Whole currency units for axis ticks - decimals are noise on an axis."""
    return f"{cents // 100:,}"


def nice_ticks(max_cents: int, count: int = 4) -> list[int]:
    """Tick values rounded to clean numbers, covering 0..max_cents."""
    if max_cents <= 0:
        return [0]
    raw = max_cents / count
    magnitude = 10 ** int(math.floor(math.log10(raw)))
    step = magnitude * 10
    for multiplier in (1, 2, 2.5, 5, 10):
        if multiplier * magnitude >= raw:
            step = multiplier * magnitude
            break
    step = max(1, int(step))
    top = step * math.ceil(max_cents / step)
    return [i * step for i in range(top // step + 1)]


# --- page shell -----------------------------------------------------------


def page(*, title: str, body: str, active: str = "") -> str:
    links = (
        ("dashboard", "/", "Dashboard"),
        ("transactions", "/transactions", "Transactions"),
    )
    current = ' class="current" aria-current="page"'
    nav = "".join(
        f'<a href="{href}"{current if active == key else ""}>{esc(text)}</a>'
        for key, href, text in links
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<link rel="stylesheet" href="/static/app.css">
</head>
<body>
<header class="topbar">
  <span class="brand">LifePilot <span class="brand-dim">Finance</span></span>
  <nav>{nav}</nav>
  <button type="button" id="theme-toggle" class="ghost-btn" aria-live="polite">Theme</button>
</header>
<main>
{body}
</main>
<div id="tooltip" role="status" aria-live="polite" hidden></div>
<script src="/static/app.js"></script>
</body>
</html>
"""


def month_filter(*, month: str, months: list[str], action: str = "/", extra: str = "") -> str:
    """The one filter row. It scopes everything below it."""
    options = "".join(
        f'<option value="{esc(m)}"{" selected" if m == month else ""}>{esc(month_label(m))}</option>'
        for m in months
    )
    return f"""<form class="filters" method="get" action="{esc(action)}">
  <label for="month">Month</label>
  <select id="month" name="month" data-autosubmit>{options}</select>
  {extra}
  <button type="submit" class="ghost-btn">Apply</button>
</form>"""


# --- stat tiles -----------------------------------------------------------


def _delta(current: int, previous: int | None) -> str:
    """Signed change vs the previous month. Arrow + words, never color alone."""
    if previous is None:
        return '<p class="delta delta-flat">no prior month to compare</p>'
    change = current - previous
    if change == 0:
        return '<p class="delta delta-flat">&#8212; unchanged vs last month</p>'
    good = change > 0  # for net, up is good
    arrow = "&#9650;" if change > 0 else "&#9660;"
    word = "up" if change > 0 else "down"
    cls = "delta-good" if good else "delta-bad"
    return (
        f'<p class="delta {cls}">{arrow} {word} {esc(format_money(abs(change)))} '
        f"vs last month</p>"
    )


def headline(*, month: str, summary: Summary, previous: Summary | None) -> str:
    """Hero figure plus the KPI row. Exactly one hero per view."""
    prev_net = previous.net_cents if previous else None
    tiles = [
        ("Income", format_money(summary.income_cents)),
        ("Expenses", format_money(summary.expense_cents)),
        ("Saved", f"{summary.savings_rate:.1%}" if summary.income_cents > 0 else "n/a"),
        ("Transactions", f"{summary.count:,}"),
    ]
    tile_html = "".join(
        f'<div class="tile"><p class="tile-label">{esc(label)}</p>'
        f'<p class="tile-value">{esc(value)}</p></div>'
        for label, value in tiles
    )
    return f"""<section class="headline">
  <div class="card hero">
    <p class="tile-label">Net &middot; {esc(month_label(month))}</p>
    <p class="hero-value">{esc(format_money(summary.net_cents))}</p>
    {_delta(summary.net_cents, prev_net)}
    <p class="note">Transfers between your own accounts are excluded.</p>
  </div>
  <div class="card tiles">{tile_html}</div>
</section>"""


# --- category breakdown (CSS bars) ----------------------------------------


def category_chart(totals: list[CategoryTotal], *, month: str, limit: int = 12) -> str:
    """Horizontal bars: magnitude by category, one series so one color.

    Horizontal because category names are long; names and values are real text
    outside the bar, so nothing can be clipped by a short bar.
    """
    if not totals:
        return _empty_card("Spending by category", "No spending recorded for this month.")

    shown = totals[:limit]
    if len(totals) > limit:
        rest = totals[limit:]
        shown = shown + [
            CategoryTotal(
                category="Other",
                total_cents=sum(t.total_cents for t in rest),
                count=sum(t.count for t in rest),
                share=sum(t.share for t in rest),
            )
        ]

    biggest = max(t.total_cents for t in shown) or 1
    rows = "".join(
        f"""<div class="bar-row" tabindex="0"
             data-label="{esc(t.category)}"
             data-value="{esc(format_money(t.total_cents))}"
             data-extra="{esc(f'{t.share:.1%} of spending · {t.count} transaction(s)')}">
      <span class="bar-name">{esc(t.category)}</span>
      <span class="bar-track"><span class="bar-fill" style="width:{t.total_cents / biggest:.4%}"></span></span>
      <span class="bar-value">{esc(format_money(t.total_cents))}</span>
    </div>"""
        for t in shown
    )

    table_rows = "".join(
        f"<tr><td>{esc(t.category)}</td><td class=\"num\">{esc(format_money(t.total_cents))}</td>"
        f"<td class=\"num\">{t.count}</td><td class=\"num\">{t.share:.1%}</td></tr>"
        for t in shown
    )
    table = _table_view(
        "category-table",
        ["Category", "Total", "Transactions", "Share"],
        table_rows,
    )

    return f"""<section class="card">
  {_card_head("Spending by category", month_label(month), "category-table")}
  <div class="bars">{rows}</div>
  {table}
</section>"""


# --- trend (inline SVG grouped columns) -----------------------------------


def trend_chart(trend: list[tuple[str, Summary]]) -> str:
    """Two series, so: a legend, plus direct labels on the most recent pair.

    Both series are currency on one shared axis - never a second y-scale.
    """
    if not trend:
        return _empty_card("Income vs expenses", "No transactions recorded yet.")

    width, height = 760, 260
    left, right, top, bottom = 58, 16, 26, 34
    plot_w = width - left - right
    plot_h = height - top - bottom

    peak = max(
        [s.income_cents for _, s in trend] + [s.expense_cents for _, s in trend] + [1]
    )
    ticks = nice_ticks(peak)
    scale_max = ticks[-1] or 1

    def y_of(cents: int) -> float:
        return top + plot_h - (cents / scale_max) * plot_h

    band = plot_w / len(trend)
    bar_w = min(24.0, max(6.0, band * 0.3))
    gap = 2.0  # surface gap: white does the separating, never a stroke

    grid = "".join(
        f'<line class="grid" x1="{left}" y1="{y_of(t):.1f}" x2="{left + plot_w}" y2="{y_of(t):.1f}"/>'
        f'<text class="tick" x="{left - 8}" y="{y_of(t) + 4:.1f}" text-anchor="end">{esc(_axis_label(t))}</text>'
        for t in ticks
    )

    marks: list[str] = []
    for index, (month, s) in enumerate(trend):
        center = left + band * (index + 0.5)
        x_income = center - bar_w - gap / 2
        x_expense = center + gap / 2
        is_last = index == len(trend) - 1

        for x, cents, series in (
            (x_income, s.income_cents, 1),
            (x_expense, s.expense_cents, 2),
        ):
            bar_h = (cents / scale_max) * plot_h
            if bar_h > 0.5:
                marks.append(
                    f'<path class="col series-{series}" d="{_column_path(x, y_of(cents), bar_w, bar_h)}"/>'
                )
            # Direct-label only the latest pair, placed above the cap so the
            # text can never be clipped by a short column.
            if is_last and cents > 0 and y_of(cents) - top > 12:
                marks.append(
                    f'<text class="col-label" x="{x + bar_w / 2:.1f}" y="{y_of(cents) - 7:.1f}" '
                    f'text-anchor="middle">{esc(_axis_label(cents))}</text>'
                )

        marks.append(
            f'<text class="tick" x="{center:.1f}" y="{top + plot_h + 20}" text-anchor="middle">'
            f"{esc(month[5:] + '/' + month[2:4])}</text>"
        )
        # Hit target spans the whole month band, so the pointer never has to
        # land on a 24px column; one tooltip reports every series.
        marks.append(
            f'<rect class="hit" x="{left + band * index:.1f}" y="{top}" width="{band:.1f}" '
            f'height="{plot_h}" tabindex="0" data-label="{esc(month_label(month))}" '
            f'data-value="{esc(format_money(s.net_cents))} net" '
            f'data-extra="Income {esc(format_money(s.income_cents))} · '
            f'Expenses {esc(format_money(s.expense_cents))}"/>'
        )

    table_rows = "".join(
        f"<tr><td>{esc(month_label(m))}</td>"
        f'<td class="num">{esc(format_money(s.income_cents))}</td>'
        f'<td class="num">{esc(format_money(s.expense_cents))}</td>'
        f'<td class="num">{esc(format_money(s.net_cents))}</td></tr>'
        for m, s in trend
    )
    table = _table_view(
        "trend-table", ["Month", "Income", "Expenses", "Net"], table_rows
    )

    return f"""<section class="card">
  {_card_head("Income vs expenses", f"last {len(trend)} month(s) with activity", "trend-table")}
  <p class="legend">
    <span class="key"><span class="swatch series-1"></span>Income</span>
    <span class="key"><span class="swatch series-2"></span>Expenses</span>
  </p>
  <svg class="chart" viewBox="0 0 {width} {height}" role="img"
       aria-label="Monthly income and expenses. The table view below lists every value.">
    {grid}
    <line class="axis" x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}"/>
    {"".join(marks)}
  </svg>
  {table}
</section>"""


def _column_path(x: float, y: float, w: float, h: float, r: float = 4.0) -> str:
    """A column with a rounded cap and a square foot on the baseline."""
    r = min(r, w / 2, h)
    return (
        f"M{x:.1f},{y + h:.1f} L{x:.1f},{y + r:.1f} Q{x:.1f},{y:.1f} {x + r:.1f},{y:.1f} "
        f"L{x + w - r:.1f},{y:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} "
        f"L{x + w:.1f},{y + h:.1f} Z"
    )


# --- budget meters --------------------------------------------------------

#: used share -> (css class, icon, wording). Status colour never travels alone.
_BUDGET_STATES = (
    (1.0, "critical", "&#10005;", "over budget"),
    (0.8, "warning", "&#33;", "close to limit"),
    (0.0, "ok", "&#10003;", "on track"),
)


def budget_meters(lines: list[BudgetLine], *, month: str) -> str:
    """A ratio against a limit is a meter, not a chart."""
    if not lines:
        return _empty_card(
            "Budget vs actual",
            "No budgets set. Add one with <code>lifepilot budget set groceries 180</code>.",
        )

    rows = []
    for line in lines:
        for threshold, state, icon, wording in _BUDGET_STATES:
            if line.used_share >= threshold:
                break
        rows.append(
            f"""<div class="meter-row" tabindex="0"
             data-label="{esc(line.category)}"
             data-value="{esc(format_money(line.spent_cents))} of {esc(format_money(line.budget_cents))}"
             data-extra="{esc(_meter_extra(line))}">
      <div class="meter-head">
        <span class="meter-name">{esc(line.category)}</span>
        <span class="status"><span class="status-icon status-{state}">{icon}</span> {esc(wording)}</span>
      </div>
      <span class="meter-track meter-{state}">
        <span class="meter-fill" style="width:{min(line.used_share, 1.0):.4%}"></span>
      </span>
      <p class="meter-foot">
        <span>{esc(format_money(line.spent_cents))} of {esc(format_money(line.budget_cents))}</span>
        <span class="num">{esc(format_money(abs(line.remaining_cents)))} {_left_or_over(line)}</span>
      </p>
    </div>"""
        )

    table_rows = "".join(
        f"<tr><td>{esc(line.category)}</td>"
        f'<td class="num">{esc(format_money(line.budget_cents))}</td>'
        f'<td class="num">{esc(format_money(line.spent_cents))}</td>'
        f'<td class="num">{esc(format_money(line.remaining_cents))}</td>'
        f'<td class="num">{line.used_share:.0%}</td></tr>'
        for line in lines
    )
    table = _table_view(
        "budget-table",
        ["Category", "Budget", "Spent", "Left", "Used"],
        table_rows,
    )

    return f"""<section class="card">
  {_card_head("Budget vs actual", month_label(month), "budget-table")}
  <div class="meters">{"".join(rows)}</div>
  {table}
</section>"""


# --- transactions ---------------------------------------------------------


def transaction_table(
    txs: list[Transaction], *, title: str, subtitle: str = "", footer: str = ""
) -> str:
    if not txs:
        return _empty_card(title, "No transactions match this view.")
    rows = "".join(
        f"<tr><td class=\"num\">{tx.id}</td><td class=\"nowrap\">{esc(tx.date.isoformat())}</td>"
        f"<td>{esc(tx.description)}</td>"
        f'<td class="num {_sign_class(tx)}">{esc(format_money(tx.amount_cents))}</td>'
        f"<td>{esc(tx.category)}</td><td>{esc(tx.account)}</td></tr>"
        for tx in txs
    )
    total = sum(tx.amount_cents for tx in txs)
    return f"""<section class="card">
  {_card_head(title, subtitle)}
  <div class="scroll-x">
    <table class="data">
      <thead><tr><th>ID</th><th>Date</th><th>Description</th><th class="num">Amount</th>
        <th>Category</th><th>Account</th></tr></thead>
      <tbody>{rows}</tbody>
      <tfoot><tr><td colspan="3">{len(txs)} transaction(s)</td>
        <td class="num">{esc(format_money(total))}</td><td colspan="2"></td></tr></tfoot>
    </table>
  </div>
  {footer}
</section>"""


# --- small shared pieces --------------------------------------------------


def _sign_class(tx: Transaction) -> str:
    return "neg" if tx.is_expense else "pos"


def _left_or_over(line: BudgetLine) -> str:
    return "over" if line.over_budget else "left"


def _meter_extra(line: BudgetLine) -> str:
    direction = _left_or_over(line)
    return (
        f"{format_money(abs(line.remaining_cents))} {direction} "
        f"· {line.used_share:.0%} used"
    )


def _card_head(title: str, subtitle: str = "", table_id: str = "") -> str:
    toggle = (
        f'<button type="button" class="ghost-btn" data-table-toggle="{esc(table_id)}" '
        f'aria-expanded="false">Table</button>'
        if table_id
        else ""
    )
    sub = f'<span class="card-sub">{esc(subtitle)}</span>' if subtitle else ""
    return f'<div class="card-head"><h2>{esc(title)}</h2>{sub}{toggle}</div>'


def _table_view(table_id: str, headers: list[str], rows: str) -> str:
    """The WCAG-clean twin of a chart: every plotted value, as text."""
    num_attr = ' class="num"'
    head = "".join(
        f'<th{num_attr if i else ""}>{esc(h)}</th>' for i, h in enumerate(headers)
    )
    return (
        f'<div class="scroll-x table-view" id="{esc(table_id)}" hidden>'
        f'<table class="data"><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table></div>'
    )


def _empty_card(title: str, message: str) -> str:
    return f'<section class="card">{_card_head(title)}<p class="empty">{message}</p></section>'


# --- full pages -----------------------------------------------------------


def dashboard(
    *,
    month: str,
    months: list[str],
    summary: Summary,
    previous: Summary | None,
    categories: list[CategoryTotal],
    trend: list[tuple[str, Summary]],
    budgets: list[BudgetLine],
    recent: list[Transaction],
) -> str:
    body = "\n".join(
        [
            month_filter(month=month, months=months),
            headline(month=month, summary=summary, previous=previous),
            category_chart(categories, month=month),
            trend_chart(trend),
            budget_meters(budgets, month=month),
            transaction_table(
                recent,
                title="Recent transactions",
                subtitle=month_label(month),
                footer=f'<p class="note"><a href="/transactions?month={esc(month)}">'
                "See all transactions for this month &rarr;</a></p>",
            ),
        ]
    )
    return page(title=f"Dashboard &middot; {month_label(month)}", body=body, active="dashboard")


def transactions_page(
    *,
    month: str,
    months: list[str],
    txs: list[Transaction],
    categories: list[str],
    category: str = "",
    query: str = "",
) -> str:
    options = "".join(
        f'<option value="{esc(c)}"{" selected" if c == category else ""}>{esc(c)}</option>'
        for c in categories
    )
    extra = f"""<label for="category">Category</label>
  <select id="category" name="category">
    <option value="">All</option>{options}
  </select>
  <label for="q">Search</label>
  <input id="q" name="q" type="search" value="{esc(query)}" placeholder="description">"""
    body = "\n".join(
        [
            month_filter(month=month, months=months, action="/transactions", extra=extra),
            transaction_table(txs, title="Transactions", subtitle=month_label(month)),
        ]
    )
    return page(
        title=f"Transactions &middot; {month_label(month)}", body=body, active="transactions"
    )


def error_page(status: int, message: str) -> str:
    body = (
        f'<section class="card"><div class="card-head"><h2>{status}</h2></div>'
        f'<p class="empty">{esc(message)}</p>'
        '<p class="note"><a href="/">Back to the dashboard</a></p></section>'
    )
    return page(title=f"{status}", body=body)


def today_month() -> str:
    return Date.today().strftime("%Y-%m")
