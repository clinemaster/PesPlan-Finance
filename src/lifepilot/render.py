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
        ("year", "/year", "Year"),
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
      <span class="bar-track"><span class="bar-fill series-2" style="width:{t.total_cents / biggest:.4%}"></span></span>
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
        band_x, band_w = _band_edges(left, band, index)
        marks.append(
            f'<rect class="hit" x="{band_x}" y="{top}" width="{band_w}" '
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


def _band_edges(left: float, band: float, index: int) -> tuple[float, float]:
    """x and width for one band, rounded so neighbours share an exact seam.

    Rounding x and width independently leaves sub-pixel overlaps or gaps
    between hit targets; deriving the width from two rounded edges does not.
    """
    start = round(left + band * index, 1)
    end = round(left + band * (index + 1), 1)
    return start, round(end - start, 1)


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


# --- yearly charts --------------------------------------------------------
#
# Two conventions hold across every chart in the app:
#
#   * Income is always series-1 (blue) and spending always series-2 (orange).
#     Color follows the entity, so a reader who learns "orange is what I spent"
#     on one chart is never shown spending in another color on the next.
#   * Last year is drawn in the de-emphasis gray, not a third hue. The current
#     year is the point and the prior year is context, which is the emphasis
#     form - and it keeps blue free to mean income only.
#
#     Do not "fix" that gray into a hue. Measured against the spending orange it
#     separates by CVD delta-E 9.8 light / 11.3 dark (>= 8 wanted) and 17.6 / 16.7
#     for normal vision (>= 15), both clear of the floors, and each clears 3:1
#     against its surface. A chroma check would fail it, but that check grades
#     categorical palettes - sets of equal, competing series - and this is one
#     accent against context, where the absence of chroma is the whole point.

MONTH_ABBR = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

# Shared plot box for the yearly charts.
_W, _H = 760, 260
_LEFT, _RIGHT, _TOP, _BOTTOM = 58, 20, 26, 34
_PLOT_W = _W - _LEFT - _RIGHT
_PLOT_H = _H - _TOP - _BOTTOM


def _scaler(peak: int):
    """Return (ticks, y_of) for a 0..peak value axis."""
    ticks = nice_ticks(max(peak, 1))
    scale_max = ticks[-1] or 1

    def y_of(cents: int) -> float:
        return _TOP + _PLOT_H - (cents / scale_max) * _PLOT_H

    return ticks, y_of


def _grid(ticks: list[int], y_of) -> str:
    return "".join(
        f'<line class="grid" x1="{_LEFT}" y1="{y_of(t):.1f}" '
        f'x2="{_LEFT + _PLOT_W}" y2="{y_of(t):.1f}"/>'
        f'<text class="tick" x="{_LEFT - 8}" y="{y_of(t) + 4:.1f}" '
        f'text-anchor="end">{esc(_axis_label(t))}</text>'
        for t in ticks
    )


def _month_ticks(band: float) -> str:
    return "".join(
        f'<text class="tick" x="{_LEFT + band * (i + 0.5):.1f}" y="{_TOP + _PLOT_H + 20}" '
        f'text-anchor="middle">{MONTH_ABBR[i]}</text>'
        for i in range(12)
    )


def _month_extra(s: Summary | None) -> str:
    if s is None:
        return "no transactions recorded"
    return (
        f"Income {format_money(s.income_cents)} \u00b7 net {format_money(s.net_cents)} "
        f"\u00b7 {s.count} transaction(s)"
    )


def monthly_spend_chart(year: int, series: list[Summary | None], *, average: int) -> str:
    """Spending month by month through one calendar year.

    One series, so one color and no legend. Months without records draw no
    column at all rather than a zero-height one, so an untouched month is never
    mistaken for a month you spent nothing in.
    """
    if all(s is None for s in series):
        return _empty_card("Spending by month", f"No transactions recorded in {year}.")

    peak = max([s.expense_cents for s in series if s] + [average, 1])
    ticks, y_of = _scaler(peak)
    band = _PLOT_W / 12
    bar_w = min(24.0, band * 0.52)

    marks: list[str] = []
    biggest = max((s.expense_cents for s in series if s), default=0)
    for index, s in enumerate(series):
        center = _LEFT + band * (index + 0.5)
        if s is not None and s.expense_cents > 0:
            x = center - bar_w / 2
            height = (s.expense_cents / (ticks[-1] or 1)) * _PLOT_H
            marks.append(
                f'<path class="col series-2" d="{_column_path(x, y_of(s.expense_cents), bar_w, height)}"/>'
            )
            # Label only the peak month - a number on every column goes unread.
            if s.expense_cents == biggest and y_of(s.expense_cents) - _TOP > 12:
                marks.append(
                    f'<text class="col-label" x="{center:.1f}" '
                    f'y="{y_of(s.expense_cents) - 7:.1f}" text-anchor="middle">'
                    f"{esc(_axis_label(s.expense_cents))}</text>"
                )
        band_x, band_w = _band_edges(_LEFT, band, index)
        marks.append(
            f'<rect class="hit" x="{band_x}" y="{_TOP}" '
            f'width="{band_w}" height="{_PLOT_H}" tabindex="0" '
            f'data-label="{MONTH_ABBR[index]} {year}" '
            f'data-value="{esc(format_money(s.expense_cents) if s else "no data")}" '
            f'data-extra="{esc(_month_extra(s))}"/>'
        )

    # The average is an annotation, not a gridline: solid hairline, labelled.
    average_line = ""
    if average > 0:
        y = y_of(average)
        average_line = (
            f'<line class="reference" x1="{_LEFT}" y1="{y:.1f}" '
            f'x2="{_LEFT + _PLOT_W}" y2="{y:.1f}"/>'
            f'<text class="reference-label" x="{_LEFT + _PLOT_W}" y="{y - 6:.1f}" '
            f'text-anchor="end">avg {esc(_axis_label(average))}</text>'
        )

    rows = "".join(
        f"<tr><td>{MONTH_ABBR[i]} {year}</td>"
        f'<td class="num">{esc(format_money(s.expense_cents)) if s else "&#8212;"}</td>'
        f'<td class="num">{esc(format_money(s.income_cents)) if s else "&#8212;"}</td>'
        f'<td class="num">{esc(format_money(s.net_cents)) if s else "&#8212;"}</td></tr>'
        for i, s in enumerate(series)
    )

    return f"""<section class="card">
  {_card_head("Spending by month", str(year), "year-months-table")}
  <svg class="chart" viewBox="0 0 {_W} {_H}" role="img"
       aria-label="Spending for each month of {year}. The table view lists every value.">
    {_grid(ticks, y_of)}
    <line class="axis" x1="{_LEFT}" y1="{_TOP + _PLOT_H}" x2="{_LEFT + _PLOT_W}" y2="{_TOP + _PLOT_H}"/>
    {average_line}
    {"".join(marks)}
    {_month_ticks(band)}
  </svg>
  {_table_view("year-months-table", ["Month", "Spent", "Income", "Net"], rows)}
</section>"""


def _line_path(points: list[tuple[float, float] | None]) -> str:
    """A polyline that breaks at missing months instead of interpolating."""
    parts: list[str] = []
    pen_down = False
    for point in points:
        if point is None:
            pen_down = False
            continue
        command = "L" if pen_down else "M"
        parts.append(f"{command}{point[0]:.1f},{point[1]:.1f}")
        pen_down = True
    return " ".join(parts)


def _isolated(points: list[tuple[float, float] | None]) -> list[tuple[float, float]]:
    """Points with no neighbour to connect to - a stroke alone would draw nothing."""
    out = []
    for i, point in enumerate(points):
        if point is None:
            continue
        before = points[i - 1] if i else None
        after = points[i + 1] if i + 1 < len(points) else None
        if before is None and after is None:
            out.append(point)
    return out


def year_over_year_chart(
    *,
    year: int,
    series: list[Summary | None],
    previous_year: int,
    previous_series: list[Summary | None],
) -> str:
    """This year's spending against last year's, month by month.

    Lines, because the shape across the year is the point. The prior year is
    drawn in the de-emphasis gray: it is context for the current year, not a
    second thing of equal weight.
    """
    has_previous = any(s is not None for s in previous_series)
    if all(s is None for s in series) and not has_previous:
        return _empty_card("Year over year", f"No transactions recorded in {year}.")

    peak = max(
        [s.expense_cents for s in series if s]
        + [s.expense_cents for s in previous_series if s]
        + [1]
    )
    ticks, y_of = _scaler(peak)
    band = _PLOT_W / 12

    def points(data: list[Summary | None]) -> list[tuple[float, float] | None]:
        return [
            (_LEFT + band * (i + 0.5), y_of(s.expense_cents)) if s is not None else None
            for i, s in enumerate(data)
        ]

    current_points = points(series)
    previous_points = points(previous_series)

    lines = ""
    if has_previous:
        lines += f'<path class="line series-context" d="{_line_path(previous_points)}"/>'
    lines += f'<path class="line series-2" d="{_line_path(current_points)}"/>'

    # End markers, plus a marker for any month that stands alone.
    markers = ""
    ends: dict[str, tuple[float, float]] = {}
    for name, pts, css in (
        ("previous", previous_points, "series-context"),
        ("current", current_points, "series-2"),
    ):
        live = [p for p in pts if p is not None]
        if not live:
            continue
        ends[name] = live[-1]
        for x, y in {*(_isolated(pts)), live[-1]}:
            markers += f'<circle class="marker {css}" cx="{x:.1f}" cy="{y:.1f}" r="4.5"/>'

    # Direct end labels, but only when they cannot collide. Nudging them apart
    # would detach each label from its line, so the legend and tooltip carry it
    # instead when the two ends are close.
    labels = ""
    separated = (
        "current" in ends
        and "previous" in ends
        and (
            abs(ends["current"][1] - ends["previous"][1]) >= 14
            or abs(ends["current"][0] - ends["previous"][0]) >= 40
        )
    )
    if separated or len(ends) == 1:
        for name, (x, y) in ends.items():
            anchor = "end" if x > _LEFT + _PLOT_W - 40 else "start"
            dx = -8 if anchor == "end" else 8
            label = str(year if name == "current" else previous_year)
            labels += (
                f'<text class="end-label" x="{x + dx:.1f}" y="{y - 8:.1f}" '
                f'text-anchor="{anchor}">{esc(label)}</text>'
            )

    # Hit bands drive both the tooltip and the crosshair; they are the full
    # height of the plot, so the pointer never has to find a 2px line.
    bands = ""
    for index in range(12):
        current, prior = series[index], previous_series[index]
        if current is None and prior is None:
            value = "no data"
        elif current is None:
            value = f"{format_money(prior.expense_cents)} in {previous_year}"
        else:
            value = format_money(current.expense_cents)
        extra_parts = []
        if prior is not None:
            extra_parts.append(f"{previous_year}: {format_money(prior.expense_cents)}")
        if current is not None and prior is not None:
            change = current.expense_cents - prior.expense_cents
            sign = "+" if change > 0 else ""
            extra_parts.append(f"{sign}{format_money(change)} year on year")
        cx = _LEFT + band * (index + 0.5)
        dots = ""
        if current is not None:
            dots += f' data-cy-current="{y_of(current.expense_cents):.1f}"'
        if prior is not None:
            dots += f' data-cy-previous="{y_of(prior.expense_cents):.1f}"'
        band_x, band_w = _band_edges(_LEFT, band, index)
        bands += (
            f'<rect class="hit" x="{band_x}" y="{_TOP}" '
            f'width="{band_w}" height="{_PLOT_H}" tabindex="0" '
            f'data-label="{MONTH_ABBR[index]} {year}" data-value="{esc(value)}" '
            f'data-extra="{esc(" \u00b7 ".join(extra_parts))}" data-cx="{cx:.1f}"{dots}/>'
        )

    rows = "".join(
        f"<tr><td>{MONTH_ABBR[i]}</td>"
        f'<td class="num">{esc(format_money(series[i].expense_cents)) if series[i] else "&#8212;"}</td>'
        f'<td class="num">{esc(format_money(previous_series[i].expense_cents)) if previous_series[i] else "&#8212;"}</td>'
        f'<td class="num">{esc(_yoy_change(series[i], previous_series[i]))}</td></tr>'
        for i in range(12)
    )

    return f"""<section class="card">
  {_card_head("Year over year", f"{year} against {previous_year}", "year-yoy-table")}
  <p class="legend">
    <span class="key"><span class="stroke series-2"></span>{year}</span>
    <span class="key"><span class="stroke series-context"></span>{previous_year}</span>
  </p>
  <svg class="chart" viewBox="0 0 {_W} {_H}" role="img"
       aria-label="Monthly spending in {year} compared with {previous_year}. The table view lists every value.">
    {_grid(ticks, y_of)}
    <line class="axis" x1="{_LEFT}" y1="{_TOP + _PLOT_H}" x2="{_LEFT + _PLOT_W}" y2="{_TOP + _PLOT_H}"/>
    <g class="crosshair">
      <line class="crosshair-line" x1="0" y1="{_TOP}" x2="0" y2="{_TOP + _PLOT_H}"/>
      <circle class="crosshair-dot series-2" data-dot="current" cx="0" cy="0" r="0"/>
      <circle class="crosshair-dot series-context" data-dot="previous" cx="0" cy="0" r="0"/>
    </g>
    {lines}
    {markers}
    {labels}
    {bands}
    {_month_ticks(band)}
  </svg>
  {_table_view("year-yoy-table", ["Month", str(year), str(previous_year), "Change"], rows)}
</section>"""


def _yoy_change(current: Summary | None, prior: Summary | None) -> str:
    if current is None or prior is None:
        return "\u2014"
    change = current.expense_cents - prior.expense_cents
    sign = "+" if change > 0 else ""
    return f"{sign}{format_money(change)}"


def year_filter(*, year: int, years: list[int]) -> str:
    options = "".join(
        f'<option value="{y}"{" selected" if y == year else ""}>{y}</option>' for y in years
    )
    return f"""<form class="filters" method="get" action="/year">
  <label for="year">Year</label>
  <select id="year" name="year" data-autosubmit>{options}</select>
  <button type="submit" class="ghost-btn">Apply</button>
</form>"""


def year_headline(*, year: int, summary: Summary, previous: Summary | None) -> str:
    """Hero figure is the year's spending - this page is about spending."""
    tiles = [
        ("Income", format_money(summary.income_cents)),
        ("Net", format_money(summary.net_cents)),
        ("Saved", f"{summary.savings_rate:.1%}" if summary.income_cents > 0 else "n/a"),
        ("Transactions", f"{summary.count:,}"),
    ]
    tile_html = "".join(
        f'<div class="tile"><p class="tile-label">{esc(label)}</p>'
        f'<p class="tile-value">{esc(value)}</p></div>'
        for label, value in tiles
    )
    # For spending, up is bad - so the delta's direction is inverted.
    delta = '<p class="delta delta-flat">no prior year to compare</p>'
    if previous is not None:
        change = summary.expense_cents - previous.expense_cents
        if change == 0:
            delta = '<p class="delta delta-flat">&#8212; unchanged vs last year</p>'
        else:
            arrow = "&#9650;" if change > 0 else "&#9660;"
            word = "up" if change > 0 else "down"
            cls = "delta-bad" if change > 0 else "delta-good"
            delta = (
                f'<p class="delta {cls}">{arrow} {word} {esc(format_money(abs(change)))} '
                f"vs {previous_year_of(year)}</p>"
            )
    return f"""<section class="headline">
  <div class="card hero">
    <p class="tile-label">Spent in {year}</p>
    <p class="hero-value">{esc(format_money(summary.expense_cents))}</p>
    {delta}
    <p class="note">Transfers between your own accounts are excluded.</p>
  </div>
  <div class="card tiles">{tile_html}</div>
</section>"""


def previous_year_of(year: int) -> int:
    return int(year) - 1


def year_totals_table(rows: list[tuple[int, Summary]]) -> str:
    """Every year side by side - the plain-text companion to the charts."""
    if not rows:
        return ""
    body = "".join(
        f"<tr><td>{y}</td>"
        f'<td class="num">{esc(format_money(s.income_cents))}</td>'
        f'<td class="num">{esc(format_money(s.expense_cents))}</td>'
        f'<td class="num">{esc(format_money(s.net_cents))}</td>'
        f'<td class="num">{s.savings_rate:.1%}</td>'
        f'<td class="num">{s.count:,}</td></tr>'
        for y, s in reversed(rows)
    )
    return f"""<section class="card">
  {_card_head("All years", f"{len(rows)} year(s) with activity")}
  <div class="scroll-x">
    <table class="data">
      <thead><tr><th>Year</th><th class="num">Income</th><th class="num">Spent</th>
        <th class="num">Net</th><th class="num">Saved</th><th class="num">Transactions</th></tr></thead>
      <tbody>{body}</tbody>
    </table>
  </div>
</section>"""


def year_page(
    *,
    year: int,
    years: list[int],
    summary: Summary,
    previous: Summary | None,
    series: list[Summary | None],
    previous_series: list[Summary | None],
    average: int,
    categories: list[CategoryTotal],
    totals: list[tuple[int, Summary]],
) -> str:
    body = "\n".join(
        [
            year_filter(year=year, years=years),
            year_headline(year=year, summary=summary, previous=previous),
            monthly_spend_chart(year, series, average=average),
            year_over_year_chart(
                year=year,
                series=series,
                previous_year=previous_year_of(year),
                previous_series=previous_series,
            ),
            category_chart(categories, month=str(year)),
            year_totals_table(totals),
        ]
    )
    return page(title=f"{year} &middot; yearly trends", body=body, active="year")


def today_year() -> int:
    return Date.today().year
