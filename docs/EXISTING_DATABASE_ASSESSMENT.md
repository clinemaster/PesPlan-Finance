# Existing Database Assessment

**Assessed:** 2026-11-25 · **Commit:** `9437392`
**Source of truth:** `src/lifepilot/db.py`
**Companion documents:** `PHASE_1_PROJECT_ASSESSMENT.md` (findings F1–F3), `EXISTING_FEATURES_INVENTORY.md` (services S1–S27), `PROPOSED_SYSTEM_ARCHITECTURE.md` (Rules 1–4)
**Method:** DDL below was read back from a live SQLite file via `sqlite_master` and `PRAGMA
table_info`, not transcribed from source. The probe database was created in the system temp
directory; **`data/` was never written to and no existing data was read, altered, or deleted.**

---

## 1. Engine

| Property | Value |
|---|---|
| Engine | **SQLite 3**, via the Python standard library `sqlite3` module |
| Driver | stdlib only — no ORM, no SQLAlchemy, no migration tool |
| Access pattern | Short-lived connection per CLI command / per HTTP request (`db.session()`) |
| Row type | `sqlite3.Row` (mapping access by column name) |
| Default location | `data/finance.db`, relative to the working directory |
| Location override | `--db PATH` per command, or the `LIFEPILOT_DB` environment variable |
| Resolution order | explicit `--db` → `$LIFEPILOT_DB` → `data/finance.db` (`db.resolve_db_path`) |
| `foreign_keys` | `ON` (set per connection in `db.connect`) |
| `journal_mode` | `delete` — the SQLite default rollback journal, **not WAL** |
| `user_version` | `1` (stamped by `init_db`; `db.SCHEMA_VERSION = 1`) |
| In-memory support | Yes — `":memory:"` is special-cased to skip directory creation; used by the test suite |

### Current state of the data directory

```
data/
└── .gitkeep
```

**No database file exists yet.** The schema lives in code and is materialized on first use by
`lifepilot init` (or implicitly by any command that opens a session). There are therefore **no
existing transaction records in the repository to preserve.** `.gitignore` excludes
`data/*.db`, `data/*.db-journal` and `data/*.csv`, so financial data is never committed.

Consequence for Phase 2: additive schema changes carry almost no migration risk *today*. That
window closes the moment real bank statements are imported.

---

## 2. Schema (verified DDL)

Three tables. No foreign keys are declared between them (see §4).

### 2.1 `transactions`

```sql
CREATE TABLE transactions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    date          TEXT    NOT NULL,
    description   TEXT    NOT NULL,
    amount_cents  INTEGER NOT NULL,
    account       TEXT    NOT NULL DEFAULT 'default',
    category      TEXT    NOT NULL DEFAULT 'uncategorized',
    notes         TEXT    NOT NULL DEFAULT '',
    fingerprint   TEXT    NOT NULL UNIQUE
);

CREATE INDEX idx_tx_date     ON transactions(date);
CREATE INDEX idx_tx_category ON transactions(category);
```

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Surrogate key, exposed in the CLI and web UI |
| `date` | TEXT NOT NULL | **ISO `YYYY-MM-DD`**, timezone-naive. Lexical order equals chronological order, which is what every range query relies on |
| `description` | TEXT NOT NULL | Free text, originates in CSV exports — **untrusted input** |
| `amount_cents` | INTEGER NOT NULL | **Signed integer cents.** Negative = expense, positive = income. Never a float |
| `account` | TEXT NOT NULL DEFAULT `'default'` | Free-text account label; not a table |
| `category` | TEXT NOT NULL DEFAULT `'uncategorized'` | Free-text category; not a table |
| `notes` | TEXT NOT NULL DEFAULT `''` | Free text; settable from the CLI only |
| `fingerprint` | TEXT NOT NULL **UNIQUE** | 32-char truncated SHA-256 used for deduplication |

**Transaction storage conventions**

- **Signed amounts in one column.** There is no separate debit/credit column and no `type`
  discriminator. Income and expense are distinguished purely by sign. CSV imports with separate
  debit/credit columns are normalized to a signed value at import time (`importers._row_amount`).
- **Both income and expense live in the same table.** "Income records" and "expense records" are
  not separate entities — a query filters on `amount_cents > 0` or `< 0`.
- **No stored currency code.** Amounts are currency-agnostic integers. Single-currency by
  assumption.
- **No created/updated timestamps.** The ledger records the transaction's own date only.

**The fingerprint (deduplication key)** — `models.Transaction.fingerprint()`:

```
sha256( f"{date.isoformat()}|{description.strip().lower()}|{amount_cents}|{account.lower()}" )[:32]
```

Case- and whitespace-insensitive on description and account. Combined with the `UNIQUE`
constraint and `INSERT OR IGNORE`, re-importing an overlapping statement export inserts nothing
and reports the skip count. This is the project's **idempotency primitive** and is directly
reusable as an API idempotency key for offline mobile sync.

### 2.2 `rules` — categorization rules

```sql
CREATE TABLE rules (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern   TEXT    NOT NULL,
    category  TEXT    NOT NULL,
    priority  INTEGER NOT NULL DEFAULT 100,
    is_regex  INTEGER NOT NULL DEFAULT 0,
    UNIQUE(pattern, category)
);
```

| Column | Notes |
|---|---|
| `pattern` | Substring (case-insensitive) or regex source, depending on `is_regex` |
| `category` | Category to assign on a match |
| `priority` | **Lower wins.** Default 100, so a specific rule uses a smaller number |
| `is_regex` | `0`/`1` boolean stored as INTEGER (SQLite has no BOOLEAN) |
| `UNIQUE(pattern, category)` | Makes `INSERT OR IGNORE` seeding idempotent |

Ordering is `ORDER BY priority ASC, id ASC` — deterministic, with insertion order breaking ties.

### 2.3 `budgets` — monthly spending limits

```sql
CREATE TABLE budgets (
    category      TEXT    PRIMARY KEY,
    monthly_cents INTEGER NOT NULL
);
```

| Column | Notes |
|---|---|
| `category` | **Natural primary key** — one budget per category, so there is no surrogate id |
| `monthly_cents` | Positive integer cents. The CLI applies `abs()` before storing |

Written with `INSERT … ON CONFLICT(category) DO UPDATE` — an upsert, so setting a budget twice
replaces rather than duplicates.

### 2.4 `sqlite_sequence`

Created automatically by SQLite because two tables use `AUTOINCREMENT`. Not application-managed.

---

## 3. Relationships

```
  transactions.category ─┐
                         ├──▶  (category name, free text — no table, no FK)
  rules.category ────────┤
  budgets.category ──────┘

  transactions.account  ──▶  (account label, free text — no table, no FK)
```

**There are no declared foreign keys**, and no `categories` or `accounts` table. Categories and
accounts are *implicit* — they exist only as strings on rows. `PRAGMA foreign_keys = ON` is set,
but no constraint currently depends on it.

### Consequences

| Consequence | Assessment |
|---|---|
| A category can be referenced by a budget or rule while no transaction uses it | **Intentional** — `budget_report` deliberately shows budgeted-but-unspent categories |
| Renaming a category requires updating rows in up to three tables | **Latent cost.** There is no rename operation today; `set-category` changes one transaction |
| Typos create new categories silently | **Real risk** as data grows. Mitigated in practice because rules, not typing, assign most categories |
| The category list is derived, not authoritative | `SELECT DISTINCT category FROM transactions` (web layer) and `list_budgets`/`list_rules` each give a partial view |

**Recommendation (Phase 2, additive and non-breaking):** keep the string columns, and add a
`categories` table as a *registry* for display metadata (label, colour, archived flag) joined on
name. Do not convert the columns to integer FKs — that is a breaking change and buys little for
a single-user ledger.

---

## 4. Financial calculation inventory

All aggregation lives in `src/lifepilot/reports.py`. **No calculation happens in SQL outside this
module, and none happens in the CLI, `web.py`, or `render.py`** — those format already-computed
values. This is the key fact that makes a shared backend feasible.

| Function | Returns | Calculation |
|---|---|---|
| `summary(conn, start, end, exclude_categories)` | `Summary` | `income = SUM(amount WHERE > 0)`; `expense = SUM(-amount WHERE < 0)`; `count` |
| `Summary.net_cents` | int | `income_cents - expense_cents` (property, signed) |
| `Summary.savings_rate` | float | `net / income`, **0.0 when income ≤ 0** (guards division by zero) |
| `by_category(…)` | `list[CategoryTotal]` | `GROUP BY category`; sign-flipped to positive magnitudes when `expenses_only`; `share` = each total ÷ grand total; sorted by magnitude desc |
| `monthly_trend(conn, months)` | `list[(month, Summary)]` | `GROUP BY substr(date,1,7)`, newest `N`, then reversed to oldest-first |
| `budget_report(conn, month)` | `list[BudgetLine]` | Per budget row, a correlated subquery sums that category's expenses in the month; sorted by `used_share` desc |
| `BudgetLine.remaining_cents` | int | `budget - spent` (negative when over) |
| `BudgetLine.used_share` | float | `spent / budget`, 0.0 when budget ≤ 0 |
| `BudgetLine.over_budget` | bool | `spent > budget` |
| `month_series(conn, year)` | `list[Summary \| None]` × 12 | Per-month summaries for a calendar year; **`None` for months with no rows** |
| `yearly_summaries(conn)` | `list[(year, Summary)]` | `GROUP BY substr(date,1,4)`, oldest-first |
| `month_average(series)` | int | Mean monthly spend **over months that have records only** |
| `month_bounds(month)` | `(start, end)` | Uses `calendar.monthrange` — leap years handled |
| `year_bounds(year)` | `(start, end)` | `YYYY-01-01` … `YYYY-12-31` |

### Business rules embedded in these calculations

These are **domain rules, not presentation choices**. Any client that recomputes totals locally
will disagree with the backend unless it reproduces all of them exactly — which is precisely why
Flutter must not try.

1. **Transfers are excluded by default.** `exclude_categories=("transfers",)` is the default
   argument on `summary`, `by_category`, `monthly_trend`, `month_series` and `yearly_summaries`.
   Moving money between your own accounts is neither income nor spending; counting it would
   double-skew every total. The seeded rule set routes anything matching `transfer` to that
   category.
2. **Expense figures are returned as positive magnitudes**, while `net_cents` keeps its sign.
   Storage is signed; report output is not. A client that treats `expense_cents` as negative
   will render double negatives.
3. **Budgets measure expenses only** (`amount_cents < 0`) and are scoped to one calendar month.
4. **`budget_report` does not apply the transfer exclusion** — it filters by the budgeted
   category name. Setting a budget on `transfers` would therefore count transfers. This is
   consistent (an explicit budget on a category is an explicit request to track it), but it is
   an asymmetry worth knowing before it surprises someone.
5. **Months with no records are not zero.** `month_series` returns `None` so that an untouched
   month is distinguishable from a month of no spending, and so a trend line is not dragged to
   the axis for months still in the future.
6. **Integer-cent arithmetic throughout.** `savings_rate`, `share` and `used_share` are the only
   floats, and all three are ratios for display, never money.

---

## 5. Initialization and migration procedures

### 5.1 Initialization

`db.connect(path)` performs the full open sequence on every call:

```python
db_path = resolve_db_path(path)          # --db → $LIFEPILOT_DB → data/finance.db
db_path.parent.mkdir(parents=True, exist_ok=True)   # skipped for ":memory:"
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
conn.execute("PRAGMA foreign_keys = ON")
init_db(conn)                            # on every connect, not just the first
```

`init_db()` runs the whole schema script and stamps the version:

```python
conn.executescript(SCHEMA)               # all CREATE … IF NOT EXISTS
conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
```

Properties:

- **Idempotent.** Every DDL statement is `CREATE TABLE/INDEX IF NOT EXISTS`, so reconnecting to a
  populated database is harmless and never destructive.
- **Implicit.** Any command creates the database if absent. The one exception is `lifepilot
  serve`, which deliberately checks for the file first and exits with *"Run `lifepilot init`
  first"* rather than serving an empty dashboard. This is why `cmd_serve` is registered with
  `needs_conn=False` — opening a session would have created the file and defeated the check.
- `lifepilot init` additionally seeds 41 starter categorization rules unless `--no-seed` is given.

### 5.2 Migration — the gap

**There is no migration runner.** `SCHEMA_VERSION` and `PRAGMA user_version` exist as a
*version stamp* but nothing reads the stored value to decide what to upgrade. Opening an older
database would add any missing tables and indexes (because of `IF NOT EXISTS`) and then
overwrite `user_version` with `1` — but:

- a **new column** on an existing table would **not** be added, because `CREATE TABLE IF NOT
  EXISTS` is a no-op on an existing table;
- there is no record of which transformation steps ran;
- a downgrade (new code, old file) is not detected.

Today this is harmless: `SCHEMA_VERSION` is 1, every deployment is at version 1, and no database
file exists. **It becomes a correctness problem the first time the schema changes**, which Phase
2 is likely to require (a `categories` registry, `user_id`, a currency code, timestamps).

### 5.3 Recommended migration approach (Phase 2, Step 1)

Keep it proportional to the project — no Alembic, no new dependency:

```python
MIGRATIONS = {
    2: ["ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'GBP'"],
    # 3: [...]
}

def migrate(conn):
    current = conn.execute("PRAGMA user_version").fetchone()[0]
    if current > SCHEMA_VERSION:
        raise RuntimeError(f"database is version {current}; this build understands {SCHEMA_VERSION}")
    with conn:                                   # one transaction per upgrade
        for version in range(current + 1, SCHEMA_VERSION + 1):
            for statement in MIGRATIONS.get(version, []):
                conn.execute(statement)
            conn.execute(f"PRAGMA user_version = {version}")
```

Rules to follow, so the preservation requirement is honoured:

1. **Additive only** — `ADD COLUMN` with a `DEFAULT`, new tables, new indexes. No `DROP`, no
   type changes, no renames of existing columns.
2. **Fail loudly on a future version** rather than silently mangling a newer file.
3. **Test the upgrade path**, not just the fresh-create path: build a v1 file, run `migrate`,
   assert the data survived.
4. **Back up before migrating.** A one-line `shutil.copy2` to `finance.db.v1.bak` before the
   first upgrade of a real file is cheap insurance.

---

## 6. Concurrency and the API

The current access pattern is one short-lived connection per command or request, which is
correct and should be kept. Two settings need attention before an API serves a phone and a
browser at once:

| Issue | Current | Recommendation |
|---|---|---|
| **Journal mode** | `delete` — writers block readers and vice versa for the duration of a write | `PRAGMA journal_mode = WAL` in `db.connect()`. Readers no longer block the writer. One-time, persistent per file, non-breaking |
| **Busy timeout** | Not set — a locked database raises `sqlite3.OperationalError` immediately | `sqlite3.connect(path, timeout=5.0)` so brief write contention retries instead of erroring |
| **Thread safety** | Already handled — `web.py` opens a connection inside each request, never shares one across threads | Keep this contract in the API (one connection per request via dependency injection) |
| **Write volume** | Single user, interactive; writes are rare and small | SQLite is the right engine. Revisit only if genuine multi-user concurrency is introduced |

---

## 7. Summary of database findings

| # | Finding | Severity | Action |
|---|---|---|---|
| D1 | No migration runner despite a version stamp | **Medium** | Add one before any schema change (Phase 2 Step 1) |
| D2 | `journal_mode = delete` | **Medium** | Switch to WAL when the API lands |
| D3 | No `busy_timeout` | Low | Pass `timeout=5.0` on connect |
| D4 | No `user_id` on any table | ~~High~~ **Closed 2026-11-26** | Single user decided. The absence of `user_id` is now correct by design, not a gap — no identity migration is needed |
| D5 | Categories/accounts are free-text with no registry | Low–Medium | Optional additive `categories` table; do not convert to FKs |
| D6 | No currency column | Low | Add with a default when multi-currency is actually needed |
| D7 | No `created_at` / `updated_at` | Low | Needed for incremental mobile sync (`?since=`); add additively |
| D8 | No "get one transaction by id" function | Low | Add `db.get_transaction`; required by `GET /transactions/{id}` |
| D9 | Database is correctly excluded from git | ✅ | …but that means git is not a data backup. Document a backup routine |
| D10 | Schema, constraints and indexes are sound for the current workload | ✅ | No change required |

**Nothing in the existing database design needs to be undone to support the API or the mobile
app.** Every recommendation above is additive.
