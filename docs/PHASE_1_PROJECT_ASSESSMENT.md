# Phase 1 — Project Assessment

**Repository:** `LifePilot-Finance`
**Assessed:** 2026-11-25
**Commit assessed:** `9437392` (`master`), working tree clean
**Scope:** assessment and documentation only — no application code, data, or schema was modified.

---

## 1. Executive summary

LifePilot-Finance is a **personal finance tracker written in Python 3.11+ with no runtime
dependencies**. It stores transactions in a single SQLite file, categorizes them with a
user-editable rule set, and reports on spending through two interfaces: a CLI
(`lifepilot …`) and a read-only local web dashboard (`lifepilot serve`).

The codebase is small (≈2,900 lines of source, ≈2,300 lines of tests), cleanly layered, and
**well positioned for the planned multi-platform evolution**. The business logic modules carry
no web or framework dependencies, so a REST API can wrap them without rewriting any financial
logic. The existing web frontend can be retained unchanged.

**Verdict: proceed to Phase 2.** Three issues should be resolved before or at the start of
Phase 2; one of them is urgent and unrelated to code.

| # | Finding | Severity | Why it matters |
|---|---|---|---|
| F1 | The `origin` remote did not exist — `git ls-remote` returned *"Repository not found"* | ~~Urgent~~ **Resolved 2026-11-25** | All work existed only on this machine. A reachable remote was configured and the history pushed; see §5 |
| F2 | No authentication, and no `user_id` anywhere in the schema | **High** | Blocks exposing the API to a mobile device over a network |
| F3 | `PRAGMA user_version` is stamped but there is no migration runner | **Medium** | Needed before any additive schema change, to honour "no breaking database changes" |

---

## 2. Project structure (verified)

```
LifePilot-Finance/
├── pyproject.toml                  27 lines   setuptools, zero runtime deps, pytest extra
├── README.md                      218 lines
├── data/                                      database location (holds only .gitkeep)
├── sample_data/transactions.csv    19 rows    example bank export
├── docs/                                      ← created by this assessment
├── src/lifepilot/
│   ├── __init__.py                  3         version
│   ├── __main__.py                  3         `python -m lifepilot`
│   ├── money.py                    61         cents ↔ text, no floats
│   ├── models.py                   91         Transaction / Rule / Budget, date parsing
│   ├── db.py                      217         schema + all SQL
│   ├── categorize.py              119         rule matching + 41 starter rules
│   ├── importers.py               134         CSV reading, column detection
│   ├── reports.py                 319         all aggregation
│   ├── render.py                  990         HTML/SVG generation for the web UI
│   ├── cli.py                     499         argparse CLI, one cmd_* per subcommand
│   ├── web.py                     468         http.server app + JSON endpoints
│   └── static/
│       ├── app.css                527         design tokens, light/dark, chart styling
│       └── app.js                 202         tooltips, crosshair, table toggles, theme
└── tests/                        1,048        172 tests across 9 files
```

Total: **2,904 lines of application source**, **1,048 lines of tests**.

---

## 3. How the application works

### 3.1 Layering

The project already separates into four layers, with dependencies pointing in one direction:

```
         ┌──────────────────────────────────────────────┐
         │  Interfaces                                   │
         │  cli.py            web.py + render.py         │
         │  (argparse)        (http.server + HTML/SVG)   │
         └───────────────┬──────────────┬───────────────┘
                         │              │
         ┌───────────────▼──────────────▼───────────────┐
         │  Domain services (framework-free)             │
         │  reports.py   categorize.py   importers.py    │
         └───────────────┬──────────────────────────────┘
                         │
         ┌───────────────▼──────────────────────────────┐
         │  Persistence                                  │
         │  db.py  (all SQL lives here)                  │
         └───────────────┬──────────────────────────────┘
                         │
         ┌───────────────▼──────────────────────────────┐
         │  Primitives                                   │
         │  models.py (dataclasses)  money.py (cents)    │
         └──────────────────────────────────────────────┘
```

**No domain or persistence module imports anything web-related.** Verified: the only imports
across `money.py`, `models.py`, `db.py`, `categorize.py`, `importers.py` and `reports.py` are
from the standard library (`sqlite3`, `csv`, `re`, `hashlib`, `decimal`, `calendar`,
`datetime`, `dataclasses`, `pathlib`, `os`) plus each other. This is the single most important
fact for Phase 2: **the API can be added as a new interface layer alongside `cli.py` and
`web.py`, with zero changes to business logic.**

### 3.2 Request / command flow

**CLI:** `cli.main()` parses arguments → opens one connection via `db.session()` → dispatches to
a `cmd_*` function → that function calls domain services → prints an aligned text table.
`serve` is the one exception: it sets `needs_conn=False` and manages its own connections.

**Web:** `web.Handler` routes a GET → opens a **connection per request** via `db.session()` →
calls a gather function (`dashboard_html`, `year_html`, `transactions_html`, `report_json`,
`year_json`) → those call the same domain services → `render.py` turns the result objects into
HTML with inline SVG. The server is read-only.

### 3.3 Core design decisions found in the code

| Decision | Where | Implication for Phase 2 |
|---|---|---|
| **Money is integer cents, never float** | `money.py`, all `*_cents` columns and fields | The API must transport integers; Flutter must use `int`, never `double` |
| **Expenses negative, income positive** | `money.py` docstring, `Transaction.is_expense` | A sign convention every client must respect |
| **Reports return expenses as positive magnitudes** | `reports.py` module docstring | `expense_cents` is positive in report output but negative in storage — a real trap for a new client |
| **Transfers excluded from reports by default** | `exclude_categories=("transfers",)` default on `summary`, `by_category`, `monthly_trend`, `month_series`, `yearly_summaries` | A business rule, not a display choice. Must not be re-implemented client-side |
| **Imports are idempotent** | `Transaction.fingerprint()` + `UNIQUE` constraint | Gives mobile offline sync a ready-made idempotency key |
| **Months without records are `None`, not zero** | `reports.month_series()` | The API must serialize these as `null`; zero-filling would misstate history |
| **Connection per operation** | `db.session()` context manager | Maps directly onto a FastAPI dependency |

---

## 4. Test baseline

Executed with the application unchanged:

```
$ .venv/Scripts/python.exe -m pytest -q
172 passed in 25.75s
```

| Test file | Tests | Covers |
|---|---|---|
| `tests/test_render.py` | 37 | HTML/SVG output, chart geometry, escaping, empty states |
| `tests/test_web.py` | 24 | Live HTTP server on a real socket, routes, headers, JSON |
| `tests/test_reports.py` | 23 | All aggregation, transfer exclusion, month/year boundaries |
| `tests/test_cli.py` | 17 | Every subcommand, exit codes, stdout/stderr |
| `tests/test_db.py` | 10 | CRUD, duplicate handling, filters, ordering |
| `tests/test_importers.py` | 10 | Column detection, debit/credit, bad rows, BOM |
| `tests/test_categorize.py` | 9 | Priority, regex, idempotent seeding, manual overrides |
| `tests/test_money.py` | 5 | Parsing, formatting, round-trips, rejection of junk |
| `tests/test_models.py` | 5 | Date formats, fingerprint stability |
| **Total** | **172** | |

**Failures: none. Errors: none. Warnings: none.**

Slowest tests are CLI and web-integration cases at ~0.7s each (process-level setup and real
sockets); the pure unit suites run in ~0.15s.

Notes for Phase 2:
- `pytest` is the only development dependency, declared as the `dev` extra.
- `tests/conftest.py` provides one fixture: an in-memory database with the schema applied.
- The web tests bind real sockets on ephemeral ports via `web.free_port()`; they are safe to
  run in CI but require loopback networking.
- There is **no coverage measurement** configured. Worth adding in Phase 2 to protect the
  business logic as the API is layered on.

---

## 5. Git and backup verification

**As assessed, 2026-11-25:**

| Check | Result |
|---|---|
| Repository | Yes, `master`, 3 commits |
| Working tree | **Clean** — no uncommitted changes, no untracked files |
| Stashes | None |
| Remote | `origin` → `https://github.com/alicialondon18-gi/LifePilot-Finance.git` |
| Remote reachable | **No** — `git ls-remote` returns `remote: Repository not found.` |
| Upstream tracking | Not configured; `master` has no upstream |
| Database in version control | No — `.gitignore` excludes `data/*.db` and `data/*.csv` (correct, but it also means git is not a data backup) |

Commit history:

```
9437392  chore: checkpoint existing LifePilot Finance implementation
4d7fae5  Add a local web UI for the reports
36c52d2  Initial commit: LifePilot Finance CLI
```

### F1 — was: there is no working backup

At the time of assessment the configured remote did not resolve, so **every line of this
project existed in exactly one place: this machine's working directory.** The recommended
action was to create the repository, push, and verify with `git ls-remote --heads origin`.

Nothing in the working tree was overwritten, discarded, or reset during this assessment.

#### Status: resolved — 2026-11-25

A reachable remote was configured and the history pushed. The remote is **not** the URL
recorded above; it was repointed to a different account and repository name:

| | |
|---|---|
| Remote | `origin` → `https://github.com/clinemaster/PesPlan-Finance.git` |
| Remote reachable | **Yes** — `git ls-remote --heads origin` returns `refs/heads/main` |
| Local branch | `main` (renamed from `master` after this assessment), tracking `origin/main` |
| Pushed through | `c37772f` — Phase 02, the full history including both earlier commits |

Two consequences worth recording rather than leaving to be discovered:

1. **The repository name does not match the project name.** The remote is *PesPlan-Finance*,
   while the codebase is LifePilot Finance throughout — the Dart package is
   `lifepilot_finance` and the Android application ID is `com.lifepilot.lifepilot_finance`.
   If this reflects a product rename rather than just a repository name, the package name and
   application ID should be changed deliberately and **before** any store release, because
   both are painful to change afterwards.
2. **The database is still not backed up by this.** `.gitignore` correctly excludes
   `data/*.db`, so pushing protects the code and never the financial data. A separate backup
   routine for the SQLite file remains outstanding — see
   `PROPOSED_SYSTEM_ARCHITECTURE.md` §7.

---

## 6. Preservation compliance

Every constraint in the Phase 1 brief was respected:

| Requirement | Status |
|---|---|
| Do not delete existing Python modules | No file deleted or renamed |
| Do not replace existing business logic | No source file modified |
| Do not delete or reset the database | No database written to (see note below) |
| Do not remove transaction records | None removed |
| Do not replace the existing web frontend | Untouched |
| Do not introduce breaking database changes | No schema change |
| Do not rewrite functionality without understanding it | Nothing rewritten |
| Do not create a second calculation engine in Flutter | No Flutter code written; the proposal explicitly forbids it |

**Note on the database:** to document the real schema rather than quoting the source, a
throwaway database was created in the system temp directory and inspected with
`PRAGMA`/`sqlite_master`. `data/` was never written to. See the next section.

---

## 7. A correction to the brief's assumptions

Two statements in the Phase 1 brief do not match the repository, and Phase 2 planning should
use the real state:

1. **There is no existing database file.** `data/` contains only `.gitkeep`. The schema exists
   in code (`db.py`) and is created on demand by `lifepilot init`. There are therefore **no
   existing transaction records to protect yet.** The preservation requirement still matters —
   as a *schema compatibility* contract, so that a database created today keeps working — but
   there is no production data at risk today. This is good news for Phase 2: additive schema
   work can be done now at near-zero migration risk, and that window closes as soon as real
   statements are imported.

2. **`src/lifepilot/render.py` was listed as an existing module and is**, but the brief's file
   list omits `__init__.py`, `__main__.py` and the `static/` assets. The inventory in section 2
   is the complete picture.

---

## 8. Readiness assessment for the multi-platform goal

| Objective | Readiness | Notes |
|---|---|---|
| Python backend shared by both apps | **Strong** | Domain layer is framework-free and fully tested |
| Retain and improve the web frontend | **Strong** | Server-rendered and self-contained; no rewrite needed |
| New Flutter app for Android and iOS | **Blocked on API + auth** | Nothing to consume yet |
| One shared database | **Ready, with caveats** | SQLite is fine for one user; needs WAL mode, and a migration runner before any change |
| Consistent financial business logic | **Strong, if the rule is enforced** | All aggregation lives in `reports.py`; the risk is a client re-implementing it |

### Gaps that must be closed in Phase 2

| Gap | Detail |
|---|---|
| **No REST API** | `web.py` serves HTML plus two JSON endpoints (`/api/report`, `/api/year`). These are read-only, unversioned, and shaped for the dashboard rather than as a general contract — but they are a useful starting point |
| **No authentication** | The server binds loopback and warns when told otherwise. Acceptable for a local dashboard, unacceptable for a phone on a network |
| ~~No multi-user model~~ | **Resolved 2026-11-26: single user, decided deliberately.** No `user_id` is needed; the schema is correct as it stands |
| **Write operations are CLI-only** | The web layer never writes. `db.py` already has the write functions a mobile client needs |
| **No migration runner** | `init_db()` is idempotent `CREATE TABLE IF NOT EXISTS` and stamps `user_version = 1`; nothing reads that version to upgrade an older file |
| **`journal_mode = delete`** | Default rollback journal. Under an API with concurrent readers, WAL is the right setting |
| **One missing read helper** | There is no "fetch transaction by id" function; `db.list_transactions()` filters but cannot select one row. A `GET /transactions/{id}` endpoint needs a small additive helper |
| **No currency field** | Amounts are currency-agnostic integers with no stored currency code. Fine for one user in one country; a constraint to acknowledge |
| **Dates are timezone-naive ISO strings** | Correct for a ledger of calendar dates; worth stating so mobile does not apply device-timezone conversion |

---

## 9. Recommended Phase 2 implementation sequence

Ordered so that each step is independently valuable and low-risk, with the riskiest
architectural decisions made early but implemented late.

**Step 0 — Secure the work** — ✅ **done 2026-11-25.**
Remote configured and history pushed; `git ls-remote` succeeds. *(F1 resolved — see §5.)*
Still outstanding: a backup routine for `data/finance.db`, which git deliberately excludes.

**Step 1 — Database foundations** *(small, enables everything after)*
- Add a migration runner driven by `PRAGMA user_version`, with `SCHEMA_VERSION` already in
  `db.py` as the target. Test upgrading a v1 file.
- Switch to `journal_mode = WAL` in `db.connect()`.
- Add the missing `db.get_transaction(conn, tx_id)` helper.
- No column changes yet. All additive, all behind existing tests.

**Step 2 — Service boundary and schemas** *(no behaviour change)*
- Introduce `src/lifepilot/api/schemas.py` with request/response models.
- Lift the gather logic in `web.report_json` / `web.year_json` into reusable service functions
  so both the HTML dashboard and the API consume one implementation.
- The existing 172 tests must still pass untouched — that is the regression gate.

**Step 3 — Read-only API v1** *(first deliverable a phone can consume)*
- FastAPI app as an optional extra (`pip install -e ".[api]"`), so the core stays dependency-free.
- `GET` endpoints for transactions, reports, budgets, rules, metadata.
- Token authentication from the start, even single-user.
- OpenAPI schema published — this is what generates the Flutter client.

**Step 4 — Write API** *(mobile becomes useful)*
- `POST`/`PATCH`/`DELETE` transactions, CSV import, budget and rule management, recategorize.
- Idempotency via the existing `fingerprint`; duplicate create returns `409`.

**Step 5 — Flutter application**
- Skeleton, routing, environment config, generated API client.
- Read-only dashboard first (proves the contract), then writes, then offline cache.
- Enforced rule: **no financial aggregation in Dart.**

**Step 6 — Web frontend improvements** *(optional, non-breaking)*
- Keep server-side rendering. The existing pages need no change to coexist with the API.
- Optionally let `app.js` call the v1 API for filter changes without a full page load.

**Step 7 — Hardening**
- Coverage measurement in CI, API contract tests, rate limiting, TLS termination guidance,
  and TLS termination guidance. Multi-user `user_id` migration is **not** in scope — single
  user was decided 2026-11-26.

### Suggested gate between steps

Each step ends with: full test suite green, no modification to the files listed in section 2
unless the step explicitly says so, and a commit pushed to a working remote.

---

## 10. Companion documents

| Document | Contents |
|---|---|
| `EXISTING_DATABASE_ASSESSMENT.md` | Engine, verified DDL, conventions, initialization, migration gap |
| `EXISTING_FEATURES_INVENTORY.md` | Every CLI command, web route, and reusable service |
| `PROPOSED_SYSTEM_ARCHITECTURE.md` | Target multi-platform architecture and the rules that keep logic shared |
| `API_DESIGN_PROPOSAL.md` | Framework recommendation, endpoint catalogue, data contracts |
| `FLUTTER_ARCHITECTURE.md` | Flutter project structure, state management, routing, API layer, configuration |
