"""Core record types."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import date as Date, datetime

UNCATEGORIZED = "uncategorized"

# Tried in order; the first that parses wins. ISO first so unambiguous input
# never gets read as day/month.
DATE_FORMATS = (
    "%Y-%m-%d",
    "%Y/%m/%d",
    "%d/%m/%Y",
    "%m/%d/%Y",
    "%d-%m-%Y",
    "%d.%m.%Y",
    "%d %b %Y",
    "%d %B %Y",
)


def parse_date(value: str) -> Date:
    """Parse a date from the formats banks commonly export."""
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, Date):
        return value
    text = str(value).strip()
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    raise ValueError(f"unrecognized date: {value!r}")


@dataclass(slots=True)
class Transaction:
    date: Date
    description: str
    amount_cents: int
    account: str = "default"
    category: str = UNCATEGORIZED
    notes: str = ""
    id: int | None = None

    @property
    def is_expense(self) -> bool:
        return self.amount_cents < 0

    @property
    def month(self) -> str:
        """Month key, e.g. '2026-11'."""
        return self.date.strftime("%Y-%m")

    def fingerprint(self) -> str:
        """Stable hash used to skip re-importing the same row twice."""
        raw = f"{self.date.isoformat()}|{self.description.strip().lower()}|{self.amount_cents}|{self.account.lower()}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]

    @classmethod
    def from_row(cls, row) -> "Transaction":
        return cls(
            id=row["id"],
            date=Date.fromisoformat(row["date"]),
            description=row["description"],
            amount_cents=row["amount_cents"],
            account=row["account"],
            category=row["category"] or UNCATEGORIZED,
            notes=row["notes"] or "",
        )


@dataclass(slots=True)
class Rule:
    """Maps a description pattern onto a category."""

    pattern: str
    category: str
    priority: int = 100
    is_regex: bool = False
    id: int | None = None


@dataclass(slots=True)
class Budget:
    category: str
    monthly_cents: int
