"""CSV import.

Bank exports vary wildly, so columns are detected from the header by alias and
can always be overridden explicitly. Two shapes are supported: a single signed
`amount` column, or separate debit/credit columns.
"""

from __future__ import annotations

import csv
import os
from dataclasses import dataclass, field

from .models import UNCATEGORIZED, Transaction, parse_date
from .money import parse_money

DATE_ALIASES = ("date", "transaction date", "posted date", "posting date", "trans date", "value date")
DESC_ALIASES = ("description", "details", "payee", "name", "memo", "narrative", "merchant", "reference", "transaction")
AMOUNT_ALIASES = ("amount", "value", "transaction amount")
DEBIT_ALIASES = ("debit", "withdrawal", "withdrawals", "money out", "paid out", "debit amount")
CREDIT_ALIASES = ("credit", "deposit", "deposits", "money in", "paid in", "credit amount")


@dataclass(slots=True)
class ImportResult:
    transactions: list[Transaction] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def _find_column(headers: list[str], aliases: tuple[str, ...]) -> str | None:
    """Match a header against aliases: exact (normalized) first, then substring."""
    normalized = {h: h.strip().lower() for h in headers}
    for alias in aliases:
        for original, norm in normalized.items():
            if norm == alias:
                return original
    for alias in aliases:
        for original, norm in normalized.items():
            if alias in norm:
                return original
    return None


def read_csv(
    path: str | os.PathLike[str],
    *,
    account: str = "default",
    date_column: str | None = None,
    description_column: str | None = None,
    amount_column: str | None = None,
    flip_signs: bool = False,
    encoding: str = "utf-8-sig",
) -> ImportResult:
    """Read a CSV export into Transactions.

    `flip_signs` is for exports that write expenses as positive numbers.
    """
    result = ImportResult()

    with open(path, "r", newline="", encoding=encoding) as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            result.warnings.append("file has no header row")
            return result

        headers = [h for h in reader.fieldnames if h]
        date_col = date_column or _find_column(headers, DATE_ALIASES)
        desc_col = description_column or _find_column(headers, DESC_ALIASES)
        amount_col = amount_column or _find_column(headers, AMOUNT_ALIASES)
        debit_col = _find_column(headers, DEBIT_ALIASES) if not amount_col else None
        credit_col = _find_column(headers, CREDIT_ALIASES) if not amount_col else None

        missing = []
        if not date_col:
            missing.append("date")
        if not desc_col:
            missing.append("description")
        if not amount_col and not (debit_col or credit_col):
            missing.append("amount (or debit/credit)")
        if missing:
            raise ValueError(
                f"could not find column(s) {', '.join(missing)} in {headers}. "
                "Pass --date-column/--description-column/--amount-column to say which to use."
            )

        for line_no, row in enumerate(reader, start=2):
            try:
                tx_date = parse_date(row[date_col])
                description = (row[desc_col] or "").strip()
                if not description:
                    description = "(no description)"
                cents = _row_amount(row, amount_col, debit_col, credit_col)
            except (ValueError, KeyError, TypeError) as exc:
                result.warnings.append(f"line {line_no}: skipped ({exc})")
                continue

            if flip_signs:
                cents = -cents

            result.transactions.append(
                Transaction(
                    date=tx_date,
                    description=description,
                    amount_cents=cents,
                    account=account,
                    category=UNCATEGORIZED,
                )
            )

    return result


def _row_amount(
    row: dict[str, str],
    amount_col: str | None,
    debit_col: str | None,
    credit_col: str | None,
) -> int:
    if amount_col:
        return parse_money(row[amount_col])

    debit = (row.get(debit_col) or "").strip() if debit_col else ""
    credit = (row.get(credit_col) or "").strip() if credit_col else ""
    if debit and credit:
        # Some exports put 0 in the unused column rather than leaving it blank.
        debit_cents, credit_cents = parse_money(debit), parse_money(credit)
        if debit_cents and credit_cents:
            raise ValueError("row has both a debit and a credit amount")
        return -abs(debit_cents) if debit_cents else abs(credit_cents)
    if debit:
        return -abs(parse_money(debit))
    if credit:
        return abs(parse_money(credit))
    raise ValueError("row has no amount")
