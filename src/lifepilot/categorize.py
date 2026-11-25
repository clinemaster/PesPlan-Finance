"""Rule-based categorization of transaction descriptions.

A rule is a pattern plus the category to assign. Substring rules (the default)
match case-insensitively anywhere in the description; regex rules are matched
with `re.search`. Lower `priority` wins, and ties fall back to rule id, so
behaviour stays deterministic.
"""

from __future__ import annotations

import re
import sqlite3
from collections.abc import Iterable

from . import db
from .models import UNCATEGORIZED, Rule

# Seed rules for a fresh database. Deliberately short on purpose: they are a
# starting point the user edits, not an attempt at a complete taxonomy.
DEFAULT_RULES: tuple[tuple[str, str], ...] = (
    ("salary", "income"),
    ("payroll", "income"),
    ("interest", "income"),
    ("refund", "income"),
    ("rent", "housing"),
    ("mortgage", "housing"),
    ("council tax", "housing"),
    ("electric", "utilities"),
    ("water", "utilities"),
    ("internet", "utilities"),
    ("broadband", "utilities"),
    ("mobile", "utilities"),
    ("supermarket", "groceries"),
    ("grocery", "groceries"),
    ("tesco", "groceries"),
    ("aldi", "groceries"),
    ("lidl", "groceries"),
    ("whole foods", "groceries"),
    ("restaurant", "dining"),
    ("cafe", "dining"),
    ("coffee", "dining"),
    ("uber eats", "dining"),
    ("doordash", "dining"),
    ("uber", "transport"),
    ("lyft", "transport"),
    ("fuel", "transport"),
    ("petrol", "transport"),
    ("gas station", "transport"),
    ("railway", "transport"),
    ("transit", "transport"),
    ("pharmacy", "health"),
    ("doctor", "health"),
    ("dental", "health"),
    ("gym", "health"),
    ("insurance", "insurance"),
    ("netflix", "subscriptions"),
    ("spotify", "subscriptions"),
    ("amazon prime", "subscriptions"),
    ("icloud", "subscriptions"),
    ("transfer", "transfers"),
    ("atm", "cash"),
)


def match_rule(description: str, rules: Iterable[Rule]) -> Rule | None:
    """Return the first rule matching the description, or None."""
    text = description.lower()
    ordered = sorted(rules, key=lambda r: (r.priority, r.id if r.id is not None else 0))
    for rule in ordered:
        if rule.is_regex:
            try:
                if re.search(rule.pattern, description, re.IGNORECASE):
                    return rule
            except re.error:
                # A malformed stored pattern should never break a whole import.
                continue
        elif rule.pattern.lower() in text:
            return rule
    return None


def categorize(description: str, rules: Iterable[Rule]) -> str:
    """Category for a description, or UNCATEGORIZED when nothing matches."""
    rule = match_rule(description, rules)
    return rule.category if rule else UNCATEGORIZED


def seed_default_rules(conn: sqlite3.Connection) -> int:
    """Insert the starter ruleset. Existing rules are left alone."""
    added = 0
    for pattern, category in DEFAULT_RULES:
        if db.add_rule(conn, Rule(pattern=pattern, category=category)) is not None:
            added += 1
    return added


def apply_rules(conn: sqlite3.Connection, *, only_uncategorized: bool = True) -> int:
    """Re-run the ruleset over stored transactions. Returns rows changed."""
    rules = db.list_rules(conn)
    if not rules:
        return 0

    sql = "SELECT id, description, category FROM transactions"
    if only_uncategorized:
        sql += " WHERE category = ?"
        rows = conn.execute(sql, (UNCATEGORIZED,)).fetchall()
    else:
        rows = conn.execute(sql).fetchall()

    updates = []
    for row in rows:
        new_category = categorize(row["description"], rules)
        if new_category != UNCATEGORIZED and new_category != row["category"]:
            updates.append((new_category, row["id"]))

    if updates:
        with conn:
            conn.executemany("UPDATE transactions SET category = ? WHERE id = ?", updates)
    return len(updates)
