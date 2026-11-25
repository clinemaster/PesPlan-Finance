import pytest

from lifepilot.money import format_money, parse_money


@pytest.mark.parametrize(
    "text,cents",
    [
        ("12.34", 1234),
        ("-12.34", -1234),
        ("$1,234.56", 123456),
        ("(45.00)", -4500),
        ("+7", 700),
        ("0.005", 1),  # rounds half up
        ("1234", 123400),
    ],
)
def test_parse_money(text, cents):
    assert parse_money(text) == cents


def test_parse_money_numeric_types():
    assert parse_money(10) == 1000
    assert parse_money(10.5) == 1050


@pytest.mark.parametrize("bad", ["", "   ", "abc", "1.2.3", "$"])
def test_parse_money_rejects_junk(bad):
    with pytest.raises(ValueError):
        parse_money(bad)


@pytest.mark.parametrize(
    "cents,text",
    [(1234, "12.34"), (-1234, "-12.34"), (0, "0.00"), (5, "0.05"), (123456789, "1,234,567.89")],
)
def test_format_money(cents, text):
    assert format_money(cents) == text


def test_round_trip():
    for cents in (-99999, -1, 0, 1, 250, 123456):
        assert parse_money(format_money(cents)) == cents
