from datetime import date

import pytest

from lifepilot.models import Transaction, parse_date


@pytest.mark.parametrize(
    "text,expected",
    [
        ("2026-11-25", date(2026, 11, 25)),
        ("25/11/2026", date(2026, 11, 25)),
        ("2026/11/25", date(2026, 11, 25)),
        ("25-11-2026", date(2026, 11, 25)),
        ("25 Nov 2026", date(2026, 11, 25)),
    ],
)
def test_parse_date(text, expected):
    assert parse_date(text) == expected


def test_parse_date_rejects_junk():
    with pytest.raises(ValueError):
        parse_date("not a date")


def test_month_and_sign():
    tx = Transaction(date=date(2026, 11, 2), description="Coffee", amount_cents=-540)
    assert tx.month == "2026-11"
    assert tx.is_expense


def test_fingerprint_ignores_case_and_padding():
    a = Transaction(date=date(2026, 11, 2), description="  Coffee  ", amount_cents=-540)
    b = Transaction(date=date(2026, 11, 2), description="COFFEE", amount_cents=-540)
    assert a.fingerprint() == b.fingerprint()


def test_fingerprint_distinguishes_amount():
    a = Transaction(date=date(2026, 11, 2), description="Coffee", amount_cents=-540)
    b = Transaction(date=date(2026, 11, 2), description="Coffee", amount_cents=-640)
    assert a.fingerprint() != b.fingerprint()
