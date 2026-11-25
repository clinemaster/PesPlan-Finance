# Existing Features Inventory

**Assessed:** 2026-11-25 · **Commit:** `9437392`
**Companion documents:** `PHASE_1_PROJECT_ASSESSMENT.md` (findings F1–F3),
`EXISTING_DATABASE_ASSESSMENT.md` (findings D1–D10)

This is a complete catalogue of what the application does today: every CLI command, every web
route, every reusable service, and which of them should eventually be exposed through a REST
API. Nothing here was changed.

---

## 1. Interfaces at a glance

| Interface | Entry point | Capability | Read/write |
|---|---|---|---|
| CLI | `lifepilot …` / `python -m lifepilot` | Full — the only way to record or edit data | Read **and** write |
| Web dashboard | `lifepilot serve` → `http://127.0.0.1:8765` | Reporting and browsing only | **Read only** |
| JSON endpoints | `/api/report`, `/api/year` | Two dashboard-shaped payloads | **Read only** |

**The single most important asymmetry:** the web layer cannot write. Every mutation —
recording a transaction, importing a statement, fixing a category, setting a budget — is
CLI-only. A mobile app needs write access, so Phase 2 must expose the write services that
already exist in `db.py` but have never had a non-CLI caller.

---

## 2. CLI commands (11 subcommands)

Global options: `--db PATH` on every command; `$LIFEPILOT_DB` as an alternative.
Date ranges accept either `--month YYYY-MM` or `--from` / `--to`.

### 2.1 Data entry and maintenance (write)

| Command | Arguments | Behaviour | Exit codes |
|---|---|---|---|
| `init` | `--no-seed` | Creates the database, applies the schema, seeds 41 starter rules unless suppressed | 0 |
| `add` | `DESCRIPTION AMOUNT` · `--date --account --category --notes` | Records one transaction. Date defaults to today; category defaults to whatever the rules match. Rejects duplicates by fingerprint | 0 ok · 1 duplicate · 2 bad amount/date |
| `import` | `PATH` · `--account --date-column --description-column --amount-column --flip-signs --dry-run --limit` | Reads a CSV export, auto-detects columns, categorizes, inserts. Reports inserted/skipped counts and per-line warnings | 0 ok · 2 unreadable file or undetectable columns |
| `recategorize` | `--all` | Re-runs the rule set. Touches only uncategorized rows unless `--all` | 0 |
| `set-category` | `ID CATEGORY` | Manual override for one transaction | 0 ok · 1 no such id |
| `delete` | `ID` | Deletes one transaction | 0 ok · 1 no such id |
| `rules add` | `PATTERN CATEGORY` · `--priority --regex` | Adds a categorization rule | 0 ok · 1 duplicate pair |
| `rules rm` | `ID` | Deletes a rule | 0 ok · 1 no such id |
| `rules seed` | — | Adds the starter rule set (idempotent) | 0 |
| `budget set` | `CATEGORY AMOUNT` | Upserts a monthly budget (`abs()` applied) | 0 |
| `budget rm` | `CATEGORY` | Removes a budget | 0 ok · 1 no such budget |

### 2.2 Reading and reporting (read)

| Command | Arguments | Output |
|---|---|---|
| `list` | `--month --from --to --category --account --search --limit` | Transaction table plus a net total |
| `rules list` | — | All rules with id, pattern, category, priority, kind |
| `budget list` | — | All budgets |
| `report summary` | `--month --from --to` | Income, expenses, net, savings rate, count |
| `report categories` | `--month --from --to --income` | Per-category totals with share and ASCII bars; `--income` breaks down income instead of spending |
| `report trend` | `--months N` (default 6) | Month-by-month income / expenses / net |
| `report year` | `--year YYYY` | Year totals, spending per month with the monthly average, year-on-year change per month, and an all-years table when more than one year has data |
| `report budget` | `--month` | Budget vs actual with used percentage and over-budget marking |

### 2.3 Serving

| Command | Arguments | Behaviour |
|---|---|---|
| `serve` | `--host` (default `127.0.0.1`) · `--port` (default `8765`) · `--open` | Starts the read-only dashboard. Refuses to start if the database file is absent (exit 2) and warns when bound to a non-loopback address |

**Implementation note worth preserving:** `serve` is registered with `needs_conn=False` so
`cli.main()` does not open a session for it. Opening one would create the database file and
defeat the "run `lifepilot init` first" check. Any future command that manages its own
connections must do the same.

---

## 3. Web application — how the four files work together

```
  Browser
     │  GET /year?year=2026
     ▼
┌──────────────────────────────────────────────────────────────────┐
│ web.py        ThreadingHTTPServer + Handler                      │
│               · routes the path, parses the query string          │
│               · opens ONE SQLite connection for this request      │
│               · calls reports.* / db.* to gather result objects    │
│               · sends security headers, sets Content-Length       │
└───────────────────────────┬──────────────────────────────────────┘
                            │  Summary, CategoryTotal, BudgetLine,
                            │  Transaction, list[Summary | None]
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│ render.py     Pure functions: result objects ──▶ HTML string      │
│               · page() writes the shell, nav, <head>, tooltip div │
│               · one function per card (headline, category_chart,  │
│                 trend_chart, monthly_spend_chart,                 │
│                 year_over_year_chart, budget_meters, tables)      │
│               · charts are inline SVG with geometry computed in   │
│                 Python; bars and meters are CSS widths            │
│               · html.escape() on every value from the database    │
└───────────────────────────┬──────────────────────────────────────┘
                            │  <link href="/static/app.css">
                            │  <script src="/static/app.js">
                            ▼
┌──────────────────────────────────┐  ┌───────────────────────────┐
│ static/app.css                    │  │ static/app.js             │
│ · design tokens on :root          │  │ · tooltips from data-*     │
│ · dark values under both          │  │   attributes via           │
│   prefers-color-scheme AND        │  │   textContent (never       │
│   [data-theme="dark"]             │  │   innerHTML)               │
│ · chart mark styling (bars,       │  │ · crosshair on the YoY     │
│   lines, markers, crosshair)      │  │   chart                    │
│ · tables, meters, stat tiles      │  │ · table-view toggles       │
│ · no layout logic in JS           │  │ · month/year filter        │
│                                   │  │   auto-submit              │
│                                   │  │ · theme toggle +           │
│                                   │  │   localStorage             │
└──────────────────────────────────┘  └───────────────────────────┘
```

**Separation of concerns is clean:** `render.py` takes already-computed report objects and
returns markup — it never queries the database, which is why it is unit-testable without a
server (37 tests do exactly that). `web.py` does the querying and never builds HTML beyond
delegating to `render`. Styling lives entirely in CSS; `app.js` adds interaction only.

### 3.1 Routes

| Route | Method | Response | Handler → renderer |
|---|---|---|---|
| `/` | GET, HEAD | Dashboard HTML | `web.dashboard_html` → `render.dashboard` |
| `/year` | GET, HEAD | Yearly trends HTML | `web.year_html` → `render.year_page` |
| `/transactions` | GET, HEAD | Transaction list HTML | `web.transactions_html` → `render.transactions_page` |
| `/api/report` | GET, HEAD | JSON — one month | `web.report_json` |
| `/api/year` | GET, HEAD | JSON — one year | `web.year_json` |
| `/static/app.css` | GET, HEAD | CSS, `max-age=300` | served from a fixed dict |
| `/static/app.js` | GET, HEAD | JS, `max-age=300` | served from a fixed dict |
| `/favicon.ico` | GET | `204 No Content` | — |
| anything else | GET | `404` HTML error page | `render.error_page` |

Query parameters: `month=YYYY-MM` (`/`, `/transactions`, `/api/report`), `year=YYYY` (`/year`,
`/api/year`), `category=`, `q=` (`/transactions`). Trailing slashes are tolerated. Only GET and
HEAD are implemented — **there is no POST handler anywhere.**

### 3.2 Pages and their content

**`/` — Dashboard** (one month)
1. Month filter — the only filter, scoping the whole page
2. Hero figure: net for the month, with delta vs the previous month
3. Stat tiles: income, expenses, savings rate, transaction count
4. Spending by category — horizontal CSS bars, one series, top 12 with the tail folded into "Other"
5. Income vs expenses — grouped SVG columns, last 12 months with activity, legend + hit bands
6. Budget vs actual — meters with status colour plus icon and wording
7. Recent transactions — 10 rows, linking to the full list

**`/year` — Yearly trends** (one calendar year)
1. Year filter
2. Hero figure: total spent in the year, with delta vs the previous year (direction inverted — spending up is bad)
3. Stat tiles: income, net, savings rate, transaction count
4. Spending by month — 12 SVG columns with a labelled average reference line; months without records draw no column
5. Year over year — two SVG lines (current year in the spending colour, prior year in de-emphasis gray), crosshair, legend, collision-checked end labels
6. Spending by category for the year
7. All years — one row per year

**`/transactions` — Transaction list**
1. Filter row: month, category dropdown, description search
2. Full table (limit 500) with a count and net total in the footer

### 3.3 Cross-cutting web behaviour

| Behaviour | Detail |
|---|---|
| **Security headers** | `Content-Security-Policy: default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self'; img-src 'self' data:; form-action 'self'; base-uri 'none'`, plus `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` |
| **Output escaping** | `render.esc()` wraps `html.escape(…, quote=True)` and is applied to every database-sourced value. Tooltip text travels in `data-*` attributes and is inserted with `textContent` |
| **No network egress** | CSP `default-src 'none'`; no CDN, no fonts, no analytics. Appropriate for financial data |
| **Works without JavaScript** | Filters are plain GET forms with a submit button; every chart has a table view containing the same values |
| **Accessibility** | Each chart carries an `aria-label` naming its table twin; hit bands are `tabindex="0"` so keyboard focus produces the same readout as hover; status is never colour-alone |
| **Theming** | Follows the OS setting, with a toggle that overrides it, persisted in `localStorage` |
| **Caching** | HTML `no-store`; static assets `max-age=300` |
| **Binding** | Loopback by default; a non-loopback `--host` prints an explicit warning (there is no authentication — F2) |
| **Port conflicts** | `web.Server` sets `SO_EXCLUSIVEADDRUSE` on Windows so a busy port fails cleanly instead of being hijacked |

---

## 4. Business logic inventory

### 4.1 Money handling — `money.py` (61 lines)

| Function | Purpose | Notes for API reuse |
|---|---|---|
| `parse_money(value)` | Text/number → integer cents | Accepts `12.34`, `$1,234.56`, `(45.00)` accounting negatives, `+7`, ints, floats, `Decimal`. Uses `Decimal` with `ROUND_HALF_UP`. Raises `ValueError` on junk |
| `format_money(cents, symbol="")` | Integer cents → `-1,234.56` | Display only |

**Rule:** no float ever touches a monetary value. `parse_money` is the single input boundary and
`format_money` the single output boundary.

### 4.2 Domain models — `models.py` (91 lines)

| Item | Purpose |
|---|---|
| `Transaction` | `date, description, amount_cents, account, category, notes, id`; properties `is_expense`, `month`; `fingerprint()`; `from_row()` |
| `Rule` | `pattern, category, priority, is_regex, id` |
| `Budget` | `category, monthly_cents` |
| `parse_date(value)` | Accepts 8 formats, ISO first so unambiguous input is never read as day/month. Returns `datetime.date` |
| `UNCATEGORIZED` | The `"uncategorized"` sentinel |

All three models are `@dataclass(slots=True)` — plain data, no persistence behaviour. They map
cleanly onto API schemas.

### 4.3 Persistence — `db.py` (217 lines)

Every SQL statement in the project lives here. Full function list in
`EXISTING_DATABASE_ASSESSMENT.md`; the API-relevant grouping:

| Group | Functions |
|---|---|
| Connection | `resolve_db_path`, `connect`, `init_db`, `session` |
| Transactions | `add_transaction`, `add_transactions`, `list_transactions`, `set_category`, `delete_transaction` |
| Rules | `add_rule`, `list_rules`, `delete_rule` |
| Budgets | `set_budget`, `list_budgets`, `delete_budget` |

`list_transactions` supports `start, end, category, account, search, limit` — but **no offset**,
so it cannot paginate, and **no by-id lookup** exists (D8).

### 4.4 Categorization — `categorize.py` (119 lines)

| Function | Purpose |
|---|---|
| `match_rule(description, rules)` | First matching rule by `(priority, id)`. Substring matches are case-insensitive; regex rules use `re.search`. A malformed stored regex is skipped, never raised |
| `categorize(description, rules)` | The matched category, or `UNCATEGORIZED` |
| `seed_default_rules(conn)` | Inserts the 41 starter rules; idempotent, returns how many were added |
| `apply_rules(conn, only_uncategorized=True)` | Re-runs rules over stored rows; returns rows changed |
| `DEFAULT_RULES` | 41 `(pattern, category)` pairs across income, housing, utilities, groceries, dining, transport, health, insurance, subscriptions, transfers, cash |

**Business rule:** `apply_rules` leaves already-categorized rows alone unless `only_uncategorized=False`,
so manual `set-category` corrections survive a re-run.

### 4.5 Import — `importers.py` (134 lines)

| Function | Purpose |
|---|---|
| `read_csv(path, account, date_column, description_column, amount_column, flip_signs, encoding)` | Returns `ImportResult(transactions, warnings)` |
| `_find_column(headers, aliases)` | Normalized exact match first, then substring |
| `_row_amount(row, …)` | Signed `amount`, or separate debit/credit normalized to a sign |

Supported shapes: a single signed `amount` column, or `debit`/`credit` pairs. Aliases cover
`date / transaction date / posted date / posting date / trans date / value date`,
`description / details / payee / name / memo / narrative / merchant / reference / transaction`,
`amount / value / transaction amount`, plus debit and credit variants. `--flip-signs` handles
exports that write expenses as positive. Encoding defaults to `utf-8-sig` so a BOM is stripped.

**Error policy:** a row that cannot be parsed produces a warning naming its line number and is
skipped; the rest of the file still imports. A header with no detectable date/description/amount
raises `ValueError` naming the headers it saw. Blank descriptions become `"(no description)"`.

### 4.6 Reporting — `reports.py` (319 lines)

Complete calculation inventory is in `EXISTING_DATABASE_ASSESSMENT.md` §4. Summary:

| Group | Functions |
|---|---|
| Date helpers | `month_bounds`, `year_bounds`, `current_month`, `current_year` |
| Result types | `Summary` (+ `net_cents`, `savings_rate`), `CategoryTotal`, `BudgetLine` (+ `remaining_cents`, `used_share`, `over_budget`) |
| Monthly | `summary`, `by_category`, `monthly_trend`, `budget_report` |
| Yearly | `available_years`, `month_series`, `yearly_summaries`, `month_average` |

### 4.7 Data validation — where it happens

| Input | Validated by | On failure |
|---|---|---|
| Monetary amounts | `money.parse_money` | `ValueError` → CLI prints `error:` and exits 2 |
| Dates | `models.parse_date` (8 formats) | `ValueError` → exit 2 |
| Month keys | `reports.month_bounds` | `ValueError`; the web layer catches it and falls back to the newest month with data |
| Year values | `reports.year_bounds` + `int()` | Invalid year falls back in the web layer |
| CSV rows | `importers.read_csv` | Per-row warning and skip; header failure aborts with a message |
| Duplicate transactions | `UNIQUE(fingerprint)` + `INSERT OR IGNORE` | Returns `None`; caller reports a skip |
| Duplicate rules | `UNIQUE(pattern, category)` | Returns `None` |
| Malformed stored regex | `categorize.match_rule` | Rule skipped, never raised |
| HTML output | `render.esc` | Escaped |

**Validation gap for the API:** there is no type/shape validation layer, because argparse and
CSV parsing have supplied it. An HTTP API accepting JSON needs its own request validation at the
edge — which is an argument for a framework with schema validation built in
(see `API_DESIGN_PROPOSAL.md`).

---

## 5. Reusable services for the REST API

The classification that matters for Phase 2. **"Reusable as-is"** means the function can be
called from an HTTP handler with no modification.

| # | Service | Implementation | API readiness |
|---|---|---|---|
| S1 | List transactions (filtered) | `db.list_transactions` | **As-is** — but add an `offset` for pagination |
| S2 | Get one transaction | — | **Missing** (D8). Needs `db.get_transaction(conn, id)` |
| S3 | Create transaction | `db.add_transaction` + `categorize.categorize` | **As-is**. `None` return ⇒ HTTP 409 |
| S4 | Bulk create | `db.add_transactions` | **As-is**. Returns `(inserted, skipped)` |
| S5 | Update category | `db.set_category` | **As-is**. `False` ⇒ 404 |
| S6 | Delete transaction | `db.delete_transaction` | **As-is**. `False` ⇒ 404 |
| S7 | Update notes | — | **Missing**. `notes` is writable only at insert time; a `PATCH` needs a setter |
| S8 | Import CSV | `importers.read_csv` + `db.add_transactions` | **As-is**, but takes a *path*. An upload needs a file-like overload or a temp file |
| S9 | List / add / delete rules | `db.list_rules`, `db.add_rule`, `db.delete_rule` | **As-is** |
| S10 | Seed starter rules | `categorize.seed_default_rules` | **As-is** |
| S11 | Re-apply rules | `categorize.apply_rules` | **As-is** |
| S12 | Preview categorization | `categorize.categorize` | **As-is** — pure function, no database. Useful for live client-side preview |
| S13 | List / set / delete budgets | `db.list_budgets`, `db.set_budget`, `db.delete_budget` | **As-is** |
| S14 | Month summary | `reports.summary` | **As-is** |
| S15 | Category breakdown | `reports.by_category` | **As-is** |
| S16 | Monthly trend | `reports.monthly_trend` | **As-is** |
| S17 | Budget vs actual | `reports.budget_report` | **As-is** |
| S18 | Year monthly series | `reports.month_series` | **As-is**. Serialize gaps as `null` |
| S19 | Yearly totals | `reports.yearly_summaries` | **As-is** |
| S20 | Monthly average | `reports.month_average` | **As-is** — pure function |
| S21 | Available months | `web.available_months` | **Move** out of `web.py` into `reports.py` |
| S22 | Available years | `reports.available_years` | **As-is** |
| S23 | Distinct categories | inline SQL in `web.transactions_html` | **Extract** into `db.list_categories` |
| S24 | Month resolution + fallback | `web.resolve_month` | **Move** — useful default behaviour, currently web-only |
| S25 | Year resolution + fallback | `web.resolve_year` | **Move** |
| S26 | Dashboard payload | `web.report_json` | **Reshape** — already a JSON payload; re-key as the v1 contract |
| S27 | Year payload | `web.year_json` | **Reshape** — same |

### Scorecard

- **20 of 27 services are reusable with no modification.**
- **3 need relocating** out of `web.py` so the API and the HTML dashboard share one
  implementation (S21, S24, S25) — plus S23 extracted from inline SQL.
- **2 are genuinely missing** and need small additive helpers (S2 get-by-id, S7 update notes).
- **2 exist as JSON already** (S26, S27) and are the natural seed of the v1 contract.
- **1 needs an interface widening** (S8 CSV upload from a stream rather than a path).

**No service needs its logic rewritten.** This is the evidence for the Phase 1 conclusion that
the existing application can support a REST API without replacing its business logic.

---

## 6. Features deliberately absent

Recording these so Phase 2 does not mistake them for oversights, and so scope is explicit.

| Absent | Status |
|---|---|
| Authentication / users | Not implemented. Single-user by design; blocks mobile (F2, D4) |
| Any write path over HTTP | Not implemented. CLI-only by design |
| Multi-currency | Amounts are currency-agnostic integers with no currency column (D6) |
| Recurring transactions / forecasting | Not implemented |
| Account balances / reconciliation | `account` is a label; no balance is tracked |
| Attachments / receipts | Not implemented |
| Bank API / Open Banking sync | Not implemented — CSV import only |
| Export (CSV/PDF) | Not implemented; `/api/*` JSON is the only machine-readable output |
| Category rename / merge | Not implemented; would require updating up to three tables (D5) |
| Pagination | `list_transactions` has `limit` but no `offset` |
| Incremental sync | No `updated_at`, so no `?since=` is possible yet (D7) |
| Soft delete | `delete_transaction` is a hard delete |
| Audit log | Not implemented |
| Coverage measurement | pytest configured, `pytest-cov` not |

---

## 7. Test coverage of these features

172 tests, all passing. Mapping to the features above:

| Feature area | Tests | File |
|---|---|---|
| Web routes, headers, JSON, escaping, year page | 24 | `test_web.py` |
| HTML/SVG rendering, chart geometry, empty states | 37 | `test_render.py` |
| All reporting calculations | 23 | `test_reports.py` |
| Every CLI subcommand and exit code | 17 | `test_cli.py` |
| Persistence CRUD and duplicate handling | 10 | `test_db.py` |
| CSV import edge cases | 10 | `test_importers.py` |
| Categorization precedence and idempotency | 9 | `test_categorize.py` |
| Money parsing/formatting | 5 | `test_money.py` |
| Date parsing and fingerprints | 5 | `test_models.py` |

These 172 tests are the **regression gate for Phase 2**: any refactor that relocates a service
(S21–S25) or adds a helper (S2, S7) must leave all of them passing untouched.
