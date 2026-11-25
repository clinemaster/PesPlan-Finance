import re
from datetime import date

import pytest

from lifepilot import render
from lifepilot.models import Transaction
from lifepilot.reports import BudgetLine, CategoryTotal, Summary


def test_month_label():
    assert render.month_label("2026-11") == "November 2026"
    assert render.month_label("garbage") == "garbage"


@pytest.mark.parametrize(
    "month,expected",
    [("2026-11", "2026-10"), ("2026-01", "2025-12"), ("2026-12", "2026-11")],
)
def test_previous_month(month, expected):
    assert render.previous_month(month) == expected


@pytest.mark.parametrize("max_cents", [1, 99, 100, 7350, 320000, 1234567])
def test_nice_ticks_cover_the_data_and_start_at_zero(max_cents):
    ticks = render.nice_ticks(max_cents)
    assert ticks[0] == 0
    assert ticks[-1] >= max_cents
    steps = {b - a for a, b in zip(ticks, ticks[1:])}
    assert len(steps) == 1  # evenly spaced


def test_nice_ticks_of_nothing():
    assert render.nice_ticks(0) == [0]


def test_column_path_is_square_at_the_baseline():
    path = render._column_path(10, 20, 24, 80)
    # Starts and ends on the baseline (y = 100) with no curve there.
    assert path.startswith("M10.0,100.0")
    assert path.endswith("L34.0,100.0 Z")
    assert path.count("Q") == 2  # only the two top corners are rounded


def test_column_path_radius_cannot_exceed_a_short_column():
    assert "Q" in render._column_path(0, 0, 24, 1)


def test_escaping_of_untrusted_text():
    txs = [
        Transaction(
            date=date(2026, 11, 2),
            description="<script>alert('x')</script>",
            amount_cents=-500,
            id=1,
        )
    ]
    html = render.transaction_table(txs, title="T")
    assert "<script>alert" not in html
    assert "&lt;script&gt;" in html


def test_category_chart_folds_the_tail_into_other():
    totals = [
        CategoryTotal(category=f"cat{i}", total_cents=(20 - i) * 100, count=1, share=0.05)
        for i in range(15)
    ]
    html = render.category_chart(totals, month="2026-11", limit=5)
    assert "Other" in html
    assert "cat14" not in html


def test_category_chart_single_series_has_no_legend():
    totals = [CategoryTotal(category="housing", total_cents=115000, count=1, share=1.0)]
    html = render.category_chart(totals, month="2026-11")
    assert 'class="legend"' not in html
    assert html.count("bar-fill") == 1


def test_category_chart_when_empty():
    html = render.category_chart([], month="2026-11")
    assert "No spending recorded" in html


def test_trend_chart_has_legend_and_table_twin():
    trend = [
        ("2026-10", Summary(income_cents=300000, expense_cents=110000, count=2)),
        ("2026-11", Summary(income_cents=320000, expense_cents=127000, count=4)),
    ]
    html = render.trend_chart(trend)
    assert 'class="legend"' in html  # two series always get a legend
    assert html.count("class=\"col series-1\"") == 2
    assert html.count("class=\"col series-2\"") == 2
    assert 'id="trend-table"' in html
    assert html.count('class="hit"') == 2  # one hit target per month band


def test_trend_chart_direct_labels_only_the_latest_pair():
    trend = [
        ("2026-09", Summary(income_cents=300000, expense_cents=110000, count=2)),
        ("2026-10", Summary(income_cents=310000, expense_cents=115000, count=2)),
        ("2026-11", Summary(income_cents=320000, expense_cents=127000, count=4)),
    ]
    html = render.trend_chart(trend)
    assert html.count("col-label") == 2


def test_trend_chart_when_empty():
    assert "No transactions recorded yet" in render.trend_chart([])


@pytest.mark.parametrize(
    "spent,budget,state,wording",
    [
        (5000, 10000, "status-ok", "on track"),
        (9000, 10000, "status-warning", "close to limit"),
        (12000, 10000, "status-critical", "over budget"),
    ],
)
def test_budget_meter_states_pair_color_with_words(spent, budget, state, wording):
    html = render.budget_meters(
        [BudgetLine(category="groceries", budget_cents=budget, spent_cents=spent)],
        month="2026-11",
    )
    assert state in html
    assert wording in html


def test_budget_meter_fill_is_capped_at_full():
    html = render.budget_meters(
        [BudgetLine(category="groceries", budget_cents=10000, spent_cents=30000)],
        month="2026-11",
    )
    assert "width:100.0000%" in html


def test_budget_meters_when_empty():
    assert "No budgets set" in render.budget_meters([], month="2026-11")


def test_headline_delta_directions():
    summary = Summary(income_cents=320000, expense_cents=120000, count=4)
    worse = Summary(income_cents=320000, expense_cents=180000, count=4)

    assert "delta-good" in render.headline(month="2026-11", summary=summary, previous=worse)
    assert "delta-bad" in render.headline(month="2026-11", summary=worse, previous=summary)
    assert "no prior month" in render.headline(
        month="2026-11", summary=summary, previous=None
    )
    assert "unchanged" in render.headline(month="2026-11", summary=summary, previous=summary)


def test_page_marks_the_current_nav_item():
    html = render.page(title="T", body="<p>x</p>", active="transactions")
    assert 'href="/transactions" class="current"' in html
    assert '<a href="/">Dashboard</a>' in html


def test_month_filter_selects_the_active_month():
    html = render.month_filter(month="2026-10", months=["2026-11", "2026-10"])
    assert '<option value="2026-10" selected>' in html


# --- yearly charts --------------------------------------------------------


def _month(spend, income=300000, count=3):
    return Summary(income_cents=income, expense_cents=spend, count=count)


def _year(spends):
    """12 slots from a dict of {1-based month: spend} - the rest are gaps."""
    return [_month(spends[m]) if m in spends else None for m in range(1, 13)]


def test_monthly_spend_chart_draws_only_months_with_records():
    series = _year({8: 150000, 9: 160000, 10: 155000, 11: 170000})
    html = render.monthly_spend_chart(2026, series, average=158750)
    assert html.count('class="col series-2"') == 4      # not 12 zero-height bars
    assert html.count('class="hit"') == 12              # but every month is hoverable
    assert "no transactions recorded" in html           # the empty months say so
    assert 'class="legend"' not in html                 # single series, no legend


def test_monthly_spend_chart_labels_only_the_peak():
    series = _year({8: 150000, 9: 160000, 10: 155000, 11: 170000})
    html = render.monthly_spend_chart(2026, series, average=158750)
    assert html.count("col-label") == 1
    assert "1,700" in html  # the peak month's value


def test_monthly_spend_chart_average_line_is_labelled():
    series = _year({8: 150000, 11: 170000})
    html = render.monthly_spend_chart(2026, series, average=160000)
    assert 'class="reference"' in html
    assert "avg 1,600" in html


def test_monthly_spend_chart_without_an_average():
    html = render.monthly_spend_chart(2026, _year({8: 150000}), average=0)
    assert 'class="reference"' not in html


def test_monthly_spend_chart_when_the_year_is_empty():
    html = render.monthly_spend_chart(2026, [None] * 12, average=0)
    assert "No transactions recorded in 2026" in html


def test_year_over_year_draws_two_lines_with_a_context_series():
    current = _year({1: 100000, 2: 110000, 3: 105000})
    previous = _year({1: 90000, 2: 95000, 3: 120000})
    html = render.year_over_year_chart(
        year=2026, series=current, previous_year=2025, previous_series=previous
    )
    assert 'class="line series-2"' in html          # this year: the spending colour
    assert 'class="line series-context"' in html    # last year: de-emphasis gray
    assert 'class="legend"' in html
    assert "2025" in html and "2026" in html


def test_year_over_year_line_breaks_at_missing_months():
    series = _year({1: 100000, 2: 110000, 5: 105000})
    html = render.year_over_year_chart(
        year=2026, series=series, previous_year=2025, previous_series=[None] * 12
    )
    path = re.search(r'class="line series-2" d="([^"]+)"', html).group(1)
    # Two subpaths: Jan-Feb, then May on its own - never interpolated across.
    assert path.count("M") == 2


def test_year_over_year_marks_an_isolated_month():
    series = _year({5: 105000})
    html = render.year_over_year_chart(
        year=2026, series=series, previous_year=2025, previous_series=[None] * 12
    )
    assert 'class="marker series-2"' in html  # a lone point still shows


def test_year_over_year_omits_end_labels_that_would_collide():
    # Same final month, nearly identical values: the two ends sit on top of
    # each other, so the legend carries identity instead.
    current = _year({1: 100000, 6: 150000})
    previous = _year({1: 90000, 6: 150100})
    html = render.year_over_year_chart(
        year=2026, series=current, previous_year=2025, previous_series=previous
    )
    assert 'class="end-label"' not in html

    # Far apart, so direct labels are safe.
    previous = _year({1: 90000, 6: 40000})
    html = render.year_over_year_chart(
        year=2026, series=current, previous_year=2025, previous_series=previous
    )
    assert html.count('class="end-label"') == 2


def test_year_over_year_crosshair_data_per_month():
    current = _year({1: 100000})
    previous = _year({1: 90000, 2: 95000})
    html = render.year_over_year_chart(
        year=2026, series=current, previous_year=2025, previous_series=previous
    )
    assert html.count("data-cx=") == 12
    # January has both series; February only last year's.
    bands = re.findall(r'<rect class="hit"[^>]*/>', html)
    assert "data-cy-current=" in bands[0] and "data-cy-previous=" in bands[0]
    assert "data-cy-current=" not in bands[1] and "data-cy-previous=" in bands[1]
    assert "data-cy-current=" not in bands[5] and "data-cy-previous=" not in bands[5]


def test_year_over_year_reports_the_change():
    current = _year({1: 110000})
    previous = _year({1: 90000})
    html = render.year_over_year_chart(
        year=2026, series=current, previous_year=2025, previous_series=previous
    )
    assert "+200.00 year on year" in html


def test_year_over_year_when_both_years_are_empty():
    html = render.year_over_year_chart(
        year=2026, series=[None] * 12, previous_year=2025, previous_series=[None] * 12
    )
    assert "No transactions recorded in 2026" in html


def test_year_headline_inverts_the_delta_because_spending_up_is_bad():
    this_year = Summary(income_cents=1200000, expense_cents=700000, count=50)
    cheaper = Summary(income_cents=1200000, expense_cents=600000, count=50)

    spent_more = render.year_headline(year=2026, summary=this_year, previous=cheaper)
    assert "delta-bad" in spent_more
    assert "up 1,000.00 vs 2025" in spent_more

    spent_less = render.year_headline(year=2026, summary=cheaper, previous=this_year)
    assert "delta-good" in spent_less
    assert "down 1,000.00" in spent_less

    assert "no prior year" in render.year_headline(
        year=2026, summary=this_year, previous=None
    )


def test_year_headline_hero_is_the_spend():
    summary = Summary(income_cents=1200000, expense_cents=700000, count=50)
    html = render.year_headline(year=2026, summary=summary, previous=None)
    assert '<p class="hero-value">7,000.00</p>' in html
    assert "Spent in 2026" in html


def test_year_totals_table_newest_first():
    rows = [
        (2025, Summary(income_cents=1000000, expense_cents=600000, count=40)),
        (2026, Summary(income_cents=1200000, expense_cents=700000, count=50)),
    ]
    html = render.year_totals_table(rows)
    assert html.index("2026") < html.index("2025")


def test_year_totals_table_of_nothing():
    assert render.year_totals_table([]) == ""


def test_year_filter_selects_the_active_year():
    html = render.year_filter(year=2025, years=[2026, 2025])
    assert '<option value="2025" selected>' in html


def test_year_nav_entry_exists():
    assert '<a href="/year"' in render.page(title="T", body="", active="year")
