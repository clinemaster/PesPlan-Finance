"""SQLite storage layer."""

from __future__ import annotations

import os
import sqlite3
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from pathlib import Path

from .models import Budget, Rule, Transaction

SCHEMA_VERSION = 1

DEFAULT_DB_PATH = Path("data") / "finance.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS transactions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    date          TEXT    NOT NULL,
    description   TEXT    NOT NULL,
    amount_cents  INTEGER NOT NULL,
    account       TEXT    NOT NULL DEFAULT 'default',
    category      TEXT    NOT NULL DEFAULT 'uncategorized',
    notes         TEXT    NOT NULL DEFAULT '',
    fingerprint   TEXT    NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_tx_date     ON transactions(date);
CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category);

CREATE TABLE IF NOT EXISTS rules (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern   TEXT    NOT NULL,
    category  TEXT    NOT NULL,
    priority  INTEGER NOT NULL DEFAULT 100,
    is_regex  INTEGER NOT NULL DEFAULT 0,
    UNIQUE(pattern, category)
);

CREATE TABLE IF NOT EXISTS budgets (
    category      TEXT    PRIMARY KEY,
    monthly_cents INTEGER NOT NULL
);
"""


def resolve_db_path(explicit: str | os.PathLike[str] | None = None) -> Path:
    """Pick the database file: CLI flag, then $LIFEPILOT_DB, then the default."""
    if explicit:
        return Path(explicit)
    env = os.environ.get("LIFEPILOT_DB")
    return Path(env) if env else DEFAULT_DB_PATH


def connect(path: str | os.PathLike[str] | None = None) -> sqlite3.Connection:
    """Open (creating if needed) the database and make sure the schema is current."""
    db_path = resolve_db_path(path)
    if str(db_path) != ":memory:":
        db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    init_db(conn)
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    with conn:
        conn.executescript(SCHEMA)
        conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")


@contextmanager
def session(path: str | os.PathLike[str] | None = None) -> Iterator[sqlite3.Connection]:
    conn = connect(path)
    try:
        yield conn
    finally:
        conn.close()


# --- transactions ---------------------------------------------------------


def add_transaction(conn: sqlite3.Connection, tx: Transaction) -> int | None:
    """Insert one transaction. Returns its id, or None if it was a duplicate."""
    with conn:
        cur = conn.execute(
            """INSERT OR IGNORE INTO transactions
                   (date, description, amount_cents, account, category, notes, fingerprint)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                tx.date.isoformat(),
                tx.description,
                tx.amount_cents,
                tx.account,
                tx.category,
                tx.notes,
                tx.fingerprint(),
            ),
        )
    return cur.lastrowid if cur.rowcount else None


def add_transactions(conn: sqlite3.Connection, txs: Iterable[Transaction]) -> tuple[int, int]:
    """Bulk insert. Returns (inserted, skipped_as_duplicate)."""
    inserted = skipped = 0
    for tx in txs:
        if add_transaction(conn, tx) is None:
            skipped += 1
        else:
            inserted += 1
    return inserted, skipped


def list_transactions(
    conn: sqlite3.Connection,
    *,
    start: str | None = None,
    end: str | None = None,
    category: str | None = None,
    account: str | None = None,
    search: str | None = None,
    limit: int | None = None,
) -> list[Transaction]:
    sql = ["SELECT * FROM transactions WHERE 1=1"]
    params: list[object] = []
    if start:
        sql.append("AND date >= ?")
        params.append(start)
    if end:
        sql.append("AND date <= ?")
        params.append(end)
    if category:
        sql.append("AND category = ?")
        params.append(category)
    if account:
        sql.append("AND account = ?")
        params.append(account)
    if search:
        sql.append("AND description LIKE ?")
        params.append(f"%{search}%")
    sql.append("ORDER BY date DESC, id DESC")
    if limit:
        sql.append("LIMIT ?")
        params.append(limit)
    rows = conn.execute(" ".join(sql), params).fetchall()
    return [Transaction.from_row(r) for r in rows]


def set_category(conn: sqlite3.Connection, tx_id: int, category: str) -> bool:
    with conn:
        cur = conn.execute("UPDATE transactions SET category = ? WHERE id = ?", (category, tx_id))
    return cur.rowcount > 0


def delete_transaction(conn: sqlite3.Connection, tx_id: int) -> bool:
    with conn:
        cur = conn.execute("DELETE FROM transactions WHERE id = ?", (tx_id,))
    return cur.rowcount > 0


# --- rules ----------------------------------------------------------------


def add_rule(conn: sqlite3.Connection, rule: Rule) -> int | None:
    with conn:
        cur = conn.execute(
            """INSERT OR IGNORE INTO rules (pattern, category, priority, is_regex)
               VALUES (?, ?, ?, ?)""",
            (rule.pattern, rule.category, rule.priority, int(rule.is_regex)),
        )
    return cur.lastrowid if cur.rowcount else None


def list_rules(conn: sqlite3.Connection) -> list[Rule]:
    rows = conn.execute("SELECT * FROM rules ORDER BY priority ASC, id ASC").fetchall()
    return [
        Rule(
            id=r["id"],
            pattern=r["pattern"],
            category=r["category"],
            priority=r["priority"],
            is_regex=bool(r["is_regex"]),
        )
        for r in rows
    ]


def delete_rule(conn: sqlite3.Connection, rule_id: int) -> bool:
    with conn:
        cur = conn.execute("DELETE FROM rules WHERE id = ?", (rule_id,))
    return cur.rowcount > 0


# --- budgets --------------------------------------------------------------


def set_budget(conn: sqlite3.Connection, budget: Budget) -> None:
    with conn:
        conn.execute(
            """INSERT INTO budgets (category, monthly_cents) VALUES (?, ?)
               ON CONFLICT(category) DO UPDATE SET monthly_cents = excluded.monthly_cents""",
            (budget.category, budget.monthly_cents),
        )


def list_budgets(conn: sqlite3.Connection) -> list[Budget]:
    rows = conn.execute("SELECT * FROM budgets ORDER BY category").fetchall()
    return [Budget(category=r["category"], monthly_cents=r["monthly_cents"]) for r in rows]


def delete_budget(conn: sqlite3.Connection, category: str) -> bool:
    with conn:
        cur = conn.execute("DELETE FROM budgets WHERE category = ?", (category,))
    return cur.rowcount > 0
