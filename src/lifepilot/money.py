"""Money handling.

Amounts are stored as integer cents everywhere. Floats are never used for
money, so totals stay exact no matter how many transactions are summed.

Sign convention: expenses are negative, income is positive.
"""

from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

_CURRENCY_NOISE = re.compile(r"[$\u00a3\u20ac\u00a5,\s]")


def parse_money(value: str | int | float | Decimal) -> int:
    """Parse a human-written amount into integer cents.

    Accepts "12.34", "$1,234.56", "(45.00)" (accounting negative), "-7",
    and numeric types. Raises ValueError on anything else.
    """
    if isinstance(value, int) and not isinstance(value, bool):
        return value * 100
    if isinstance(value, (float, Decimal)):
        return _to_cents(Decimal(str(value)))

    text = str(value).strip()
    if not text:
        raise ValueError("empty amount")

    negative = False
    if text.startswith("(") and text.endswith(")"):
        negative = True
        text = text[1:-1]

    text = _CURRENCY_NOISE.sub("", text)
    if text.startswith("+"):
        text = text[1:]
    if not text:
        raise ValueError("empty amount")

    try:
        amount = Decimal(text)
    except InvalidOperation:
        raise ValueError(f"not a valid amount: {value!r}") from None

    if negative:
        amount = -amount
    return _to_cents(amount)


def _to_cents(amount: Decimal) -> int:
    return int((amount * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def format_money(cents: int, *, symbol: str = "") -> str:
    """Render cents as a signed decimal string, e.g. -1234 -> '-12.34'."""
    sign = "-" if cents < 0 else ""
    whole, rem = divmod(abs(cents), 100)
    return f"{sign}{symbol}{whole:,}.{rem:02d}"
