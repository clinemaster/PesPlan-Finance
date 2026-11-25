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
