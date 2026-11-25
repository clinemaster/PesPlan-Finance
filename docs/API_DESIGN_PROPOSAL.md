# REST API Design Proposal

**Status:** proposal for review — **no API code has been written**
**Date:** 2026-11-25 · **Baseline commit:** `9437392`
**Companion documents:** `EXISTING_FEATURES_INVENTORY.md` (services S1–S27),
`EXISTING_DATABASE_ASSESSMENT.md` (D1–D10), `PROPOSED_SYSTEM_ARCHITECTURE.md` (Rules 1–4)

---

## 1. Can the existing application support an API without replacing its business logic?

**Yes.** The evidence, from the assessment:

1. **The domain layer has no web coupling.** `money.py`, `models.py`, `db.py`, `categorize.py`,
   `importers.py` and `reports.py` import only the standard library and each other. An HTTP
   handler can call them directly.
2. **20 of 27 catalogued services are callable as-is** (S1–S27). Four need relocating out of
   `web.py` so HTML and JSON share one implementation; two need small additive helpers; one needs
   its input widened from a path to a stream. None needs its logic rewritten.
3. **The payload shapes already exist.** `web.report_json()` and `web.year_json()` are working
   JSON serializers over the real report objects. They were built for the dashboard, so they need
   re-keying as a stable contract — but the hard part, deciding what to expose, is done.
4. **Connection-per-request is already the pattern** in `web.py`, which maps directly onto a
   framework dependency.
5. **172 passing tests** cover the logic the API will call, so the API can be added behind a
   regression gate rather than on faith.

**What the API must supply that does not exist yet:** request validation for JSON input
(argparse and the CSV reader have been doing that job), authentication (F2), pagination
(`list_transactions` has `limit` but no `offset`), and a write path over HTTP (today writes are
CLI-only).

---

## 2. Framework recommendation: FastAPI

### Recommendation

**FastAPI, served by uvicorn, installed as an optional extra (`pip install -e ".[api]"`).**

### Why

| Reason | Detail |
|---|---|
| **OpenAPI schema for free** | This is the deciding factor. A generated schema means the Flutter client is generated, not hand-written — eliminating the most likely source of contract drift between Python and Dart |
| **Validation at the edge, logic untouched** | pydantic models in `api/schemas.py` validate and coerce requests. The domain layer never sees a request object, so Rule 3 holds |
| **Dependency injection fits the existing pattern** | `Depends(get_conn)` reproduces `db.session()` per request with correct teardown |
| **Typed signatures match the codebase** | The project already annotates thoroughly (`str \| None`, `list[Transaction]`). FastAPI consumes those annotations rather than fighting them |
| **`TestClient` for contract tests** | API tests sit alongside the existing suite with no new test infrastructure |
| **Interactive docs** | `/docs` is a genuine development aid while building the mobile client |
| **Small surface** | Two dependencies (`fastapi`, `uvicorn`) to add a REST interface to a 2,900-line project is proportionate |

### Alternatives considered

| Framework | Verdict |
|---|---|
| **Flask** | Viable and lighter. Rejected because OpenAPI, request validation and typed responses all become add-ons (flask-smorest, marshmallow) or hand-written — so the Flutter client becomes hand-written too. That trades two dependencies for ongoing contract risk |
| **Django REST Framework** | Rejected. Brings an ORM, migrations, settings module and app layout the project does not need, and would duplicate `db.py`. A rewrite disguised as a dependency |
| **Stdlib `http.server`** (extend `web.py`) | Rejected for the API, though tempting because it preserves zero dependencies. It means hand-rolling routing, JSON validation, auth and an OpenAPI document — reimplementing a framework, badly, as the mobile surface grows. **Note:** `web.py` itself stays on `http.server` and keeps the core dependency-free; only the new API package takes the dependency |
| **Litestar / Falcon** | Comparable to FastAPI; rejected only on ecosystem size for client generation and team familiarity |

### Dependency containment

```toml
[project]
dependencies = []                      # CLI + web UI remain dependency-free

[project.optional-dependencies]
dev = ["pytest>=8.0"]
api = ["fastapi>=0.115", "uvicorn[standard]>=0.30"]
```

`src/lifepilot/api/` must be imported lazily so a core-only install never imports FastAPI. The
existing `lifepilot serve` (HTML dashboard) must keep working with no extras installed.

---

## 3. Conventions

| Concern | Decision |
|---|---|
| **Base path** | `/api/v1` — the existing unversioned `/api/report` and `/api/year` stay as-is for the dashboard, and are **not** the public contract |
| **Money** | Integer cents in fields suffixed `_cents`. **No floats, no formatted-currency-only fields.** (Rule 2) |
| **Dates** | ISO `YYYY-MM-DD` strings, timezone-naive, matching storage. Clients must not apply timezone conversion |
| **Months / years** | `month=YYYY-MM`, `year=YYYY` |
| **Missing months** | `null` in a 12-slot array — never a zero-filled object (D-level rule from `month_series`) |
| **Expense sign** | Report responses carry `expense_cents` as a **positive magnitude**; `net_cents` is signed. Transaction responses carry the **signed** `amount_cents`. This mirrors the existing domain contract and must be documented on every endpoint |
| **Transfers** | Excluded from all report endpoints by default; `include_transfers=true` opts in |
| **Auth** | `Authorization: Bearer <token>` on every `/api/v1/*` request |
| **Content type** | `application/json` except CSV upload (`multipart/form-data`) |
| **Errors** | Consistent envelope (§6) |
| **Pagination** | `limit` (default 100, max 500) + `offset`, with `total` in the response |
| **Idempotency** | Transaction creation is naturally idempotent via `fingerprint`; a duplicate returns `409` with the existing id |

---

## 4. Endpoint catalogue

`✅ as-is` = backed by an existing function with no modification.
`➕ additive` = needs a small new helper.
`↔ relocate` = needs a function moved out of `web.py`.

### 4.1 Meta

| Method | Path | Purpose | Backing |
|---|---|---|---|
| GET | `/api/v1/health` | Liveness + schema version | ➕ reads `PRAGMA user_version` |
| GET | `/api/v1/meta/months` | Months with data, newest first | ↔ S21 `web.available_months` |
| GET | `/api/v1/meta/years` | Years with data, newest first | ✅ S22 `reports.available_years` |
| GET | `/api/v1/meta/categories` | Distinct categories in use | ➕ S23 extract `db.list_categories` |
| GET | `/api/v1/meta/accounts` | Distinct account labels | ➕ same pattern |

### 4.2 Transactions

| Method | Path | Purpose | Backing |
|---|---|---|---|
| GET | `/api/v1/transactions` | List with filters + pagination | ✅ S1 `db.list_transactions` (➕ `offset`) |
| GET | `/api/v1/transactions/{id}` | One transaction | ➕ S2 `db.get_transaction` **missing today** |
| POST | `/api/v1/transactions` | Create one | ✅ S3 `db.add_transaction` + `categorize.categorize` |
| POST | `/api/v1/transactions/batch` | Create many | ✅ S4 `db.add_transactions` |
| PATCH | `/api/v1/transactions/{id}` | Update `category` and/or `notes` | ✅ S5 `set_category` · ➕ S7 `set_notes` **missing today** |
| DELETE | `/api/v1/transactions/{id}` | Delete one | ✅ S6 `db.delete_transaction` |
| POST | `/api/v1/transactions/import` | CSV upload | ✅ S8 `importers.read_csv` (➕ stream overload) |

Query parameters for `GET /transactions`: `month`, `from`, `to`, `category`, `account`, `q`,
`limit`, `offset`.

### 4.3 Reports — read-only, the primary mobile surface

| Method | Path | Purpose | Backing |
|---|---|---|---|
| GET | `/api/v1/reports/summary` | Income, expenses, net, savings rate, count | ✅ S14 `reports.summary` |
| GET | `/api/v1/reports/categories` | Per-category totals with share | ✅ S15 `reports.by_category` |
| GET | `/api/v1/reports/trend` | Month-by-month, last N months | ✅ S16 `reports.monthly_trend` |
| GET | `/api/v1/reports/budget` | Budget vs actual for a month | ✅ S17 `reports.budget_report` |
| GET | `/api/v1/reports/year` | Full yearly payload | ✅ S18–S20 + S25 |
| GET | `/api/v1/reports/dashboard` | Composite: everything one dashboard screen needs, in one round trip | ↔ S26 reshape `web.report_json` |

`/reports/dashboard` exists for mobile latency: a phone on mobile data should not make six
requests to paint one screen. It composes existing services and introduces no new calculation.

### 4.4 Budgets

| Method | Path | Purpose | Backing |
|---|---|---|---|
| GET | `/api/v1/budgets` | All budgets | ✅ S13 `db.list_budgets` |
| PUT | `/api/v1/budgets/{category}` | Upsert one | ✅ S13 `db.set_budget` |
| DELETE | `/api/v1/budgets/{category}` | Remove one | ✅ S13 `db.delete_budget` |

`PUT` (not `POST`) because `set_budget` is already an upsert keyed on category — the HTTP verb
should match the existing semantics.

### 4.5 Categorization rules

| Method | Path | Purpose | Backing |
|---|---|---|---|
| GET | `/api/v1/rules` | All rules, in precedence order | ✅ S9 `db.list_rules` |
| POST | `/api/v1/rules` | Add a rule | ✅ S9 `db.add_rule` |
| DELETE | `/api/v1/rules/{id}` | Delete a rule | ✅ S9 `db.delete_rule` |
| POST | `/api/v1/rules/seed` | Add the 41 starter rules | ✅ S10 `seed_default_rules` |
| POST | `/api/v1/rules/apply` | Re-run rules (`all=bool`) | ✅ S11 `categorize.apply_rules` |
| POST | `/api/v1/rules/preview` | Which category a description would get | ✅ S12 `categorize.categorize` |

`/rules/preview` is worth having: it lets the mobile form show the category that will be assigned
as the user types, without the client knowing anything about rule precedence (Rule 1).

---

## 5. Representative contracts

### 5.1 Transaction

```jsonc
{
  "id": 42,
  "date": "2026-11-05",
  "description": "TESCO SUPERMARKET 4417",
  "amount_cents": -8235,          // SIGNED: negative = expense
  "account": "current",
  "category": "groceries",
  "notes": "",
  "is_expense": true              // derived; saves clients re-deriving the sign rule
}
```

### 5.2 `GET /api/v1/reports/summary?month=2026-11`

```jsonc
{
  "range": { "start": "2026-11-01", "end": "2026-11-30", "month": "2026-11" },
  "income_cents": 365000,
  "expense_cents": 171275,        // POSITIVE magnitude
  "net_cents": 193725,            // signed
  "savings_rate": 0.5308,         // ratio, not money; 0.0 when income <= 0
  "transactions": 17,
  "excludes_transfers": true      // the business rule, stated in the payload
}
```

`excludes_transfers` is included deliberately: a client showing a total should be able to say
*why* it differs from a raw bank balance, without hardcoding the rule.

### 5.3 `GET /api/v1/reports/year?year=2026` (abridged)

```jsonc
{
  "year": 2026,
  "summary": { "income_cents": 1335000, "expense_cents": 646859,
               "net_cents": 688141, "savings_rate": 0.5154, "transactions": 56 },
  "average_monthly_spend_cents": 161715,   // mean over months WITH records only
  "months": [
    null, null, null, null, null, null, null,        // Jan–Jul: no records, NOT zero
    { "month": "2026-08", "income_cents": 320000,
      "expense_cents": 158528, "net_cents": 161472, "transactions": 14 },
    // …
  ],
  "previous_year": { "year": 2025, "months": [ /* 12 slots */ ] },
  "categories": [ { "category": "housing", "total_cents": 1150000,
                    "count": 12, "share": 0.671 } ],
  "years": [ { "year": 2025, "income_cents": 3600000, "expense_cents": 1900000,
               "net_cents": 1700000, "transactions": 120 } ]
}
```

The `null` entries are the contract. A client must render a gap, not a zero — this is the single
most likely thing for a new client to get wrong.

### 5.4 `POST /api/v1/transactions`

Request:
```jsonc
{
  "date": "2026-11-25",
  "description": "Blue Bottle Coffee",
  "amount_cents": -540,
  "account": "current",
  "notes": ""
  // "category" omitted -> the server applies the rule set
}
```

Responses:
- `201 Created` → the full transaction, including the server-assigned `category` and `id`.
- `409 Conflict` → an identical transaction exists (same fingerprint):

```jsonc
{ "error": { "code": "duplicate_transaction",
             "message": "An identical transaction already exists.",
             "details": { "existing_id": 41 } } }
```

A client replaying a queued offline write can treat `409` as success.

### 5.5 `POST /api/v1/transactions/import`

`multipart/form-data`: `file` (CSV), plus optional `account`, `date_column`,
`description_column`, `amount_column`, `flip_signs`, `dry_run`.

```jsonc
{
  "inserted": 18,
  "skipped_duplicates": 2,
  "uncategorized": 2,
  "warnings": ["line 7: skipped (unrecognized date: 'n/a')"],
  "dry_run": false,
  "transactions": [ /* present only when dry_run = true */ ]
}
```

Mirrors the CLI's existing behaviour exactly: bad rows warn and are skipped, duplicates are
counted, and `dry_run` parses without writing.

---

## 6. Error model

One envelope for every failure:

```jsonc
{ "error": { "code": "invalid_month",
             "message": "expected a month as YYYY-MM, got 'nope'",
             "details": { "parameter": "month" } } }
```

| Status | When | Example code |
|---|---|---|
| 400 | Malformed parameter the domain rejects | `invalid_month`, `invalid_amount`, `invalid_date` |
| 401 | Missing or bad token | `unauthorized` |
| 404 | No such id or category | `transaction_not_found`, `budget_not_found` |
| 409 | Duplicate fingerprint or rule pair | `duplicate_transaction`, `duplicate_rule` |
| 413 | Upload too large | `file_too_large` |
| 422 | Request body fails schema validation | `validation_error` (FastAPI's own, reshaped) |
| 500 | Unexpected | `internal_error` — message must not leak a file path or SQL |

**Mapping existing return values:** several domain functions signal failure by return value
rather than raising — `add_transaction`/`add_rule` return `None` on duplicate; `set_category`,
`delete_transaction`, `delete_rule`, `delete_budget` return `False` when nothing matched. The
router layer translates these to `409` and `404`. Do not change the domain functions to raise.

---

## 7. Authentication

**Phase 2 (single user — decided 2026-11-26):** static bearer token.

- Token read from `LIFEPILOT_API_TOKEN` (or a `0600` secret file). Never committed.
- Verified with `secrets.compare_digest` in a FastAPI dependency applied to the whole `/api/v1`
  router.
- The API binds loopback; TLS terminates at a reverse proxy. **A token over plain HTTP across a
  network is no protection** — ship them together.
- Mobile stores the token in the OS keystore (`flutter_secure_storage`).
- Pairing convenience: display the token as a QR code from a CLI subcommand so the phone need
  not have it typed in.

**If multi-user is ever required** — not planned; single user was decided 2026-11-26 (D4) —
`user_id` on all three tables via an additive migration,
scoping enforced inside `db.py` query functions — not in routers, where one forgotten filter
becomes a data leak — plus a real credential store and session tokens. **Do not build this
speculatively.** Decide first whether LifePilot is a single-user product.

---

## 8. Versioning and compatibility

| Rule | Detail |
|---|---|
| Path versioning | `/api/v1`. A breaking change means `/api/v2`, with v1 kept until no client needs it |
| Additive is not breaking | New optional fields may appear in responses; clients must ignore unknown fields |
| Breaking | Removing or renaming a field, changing a type (notably int → float), changing the sign convention, or changing a default such as transfer exclusion |
| Contract snapshot | Commit the generated OpenAPI document and fail CI on an unreviewed diff |
| Existing dashboard endpoints | `/api/report` and `/api/year` are internal to the web UI, excluded from the OpenAPI document, and may change with the dashboard |

---

## 9. Proposed implementation shape

```
src/lifepilot/api/
├── __init__.py
├── app.py              create_app(): FastAPI instance, routers, error handlers
├── deps.py             get_conn() -> Iterator[sqlite3.Connection]; require_token()
├── schemas.py          pydantic request/response models  (the ONLY pydantic usage)
└── routers/
    ├── meta.py         health, months, years, categories, accounts
    ├── transactions.py list, get, create, batch, patch, delete, import
    ├── reports.py      summary, categories, trend, budget, year, dashboard
    ├── budgets.py      list, upsert, delete
    └── rules.py        list, add, delete, seed, apply, preview
```

Connection dependency — the existing pattern, expressed for FastAPI:

```python
def get_conn() -> Iterator[sqlite3.Connection]:
    with db.session() as conn:     # db.resolve_db_path handles --db / $LIFEPILOT_DB
        yield conn
```

Launch:
```bash
pip install -e ".[api]"
LIFEPILOT_API_TOKEN=… uvicorn lifepilot.api.app:create_app --factory --host 127.0.0.1 --port 8000
```

Optionally add a `lifepilot serve-api` subcommand that imports FastAPI lazily and prints a clear
message if the `api` extra is not installed.

---

## 10. Build order

| Step | Deliverable | Gate |
|---|---|---|
| 1 | `db.py` foundations: migration runner (D1), WAL (D2), `busy_timeout` (D3), `get_transaction` (S2), `set_notes` (S7), `list_categories` (S23), `offset` on `list_transactions` | 172 existing tests pass unchanged; new migration test passes |
| 2 | `services.py`: relocate S21, S24, S25; `web.py` calls it instead of holding the logic | 172 tests pass unchanged |
| 3 | `api/` skeleton: app factory, connection + auth dependencies, `/health`, error handlers | Auth rejects a missing token |
| 4 | Read endpoints: meta, transactions list/get, all reports | `TestClient` tests per endpoint; OpenAPI snapshot committed |
| 5 | Write endpoints: create, batch, patch, delete, import, budgets, rules | 409/404 mapping tested; import matches CLI behaviour |
| 6 | Hardening: pagination limits, upload size cap, rate limiting at the proxy, TLS runbook | Contract test green in CI |

Steps 1 and 2 are pure refactor-and-add with the existing suite as the gate; the API only starts
at step 3. **Nothing in steps 1–6 modifies `reports.py` or `categorize.py`.**

---

## 11. Open questions for review

1. ~~**Single-user or multi-user?**~~ **DECIDED 2026-11-26: single user.** (D4)
   LifePilot is a single-user product. Consequences, which Phase 03 should treat as settled:
   * **No `user_id` columns.** The schema stays as assessed. No migration is needed for
     identity, and `db.py` queries need no scoping clause.
   * **Auth is a static bearer token** (§7), not a credential store, session management or
     OAuth. One token, one person.
   * **SQLite stays** — there is no concurrency argument for Postgres (§7 of
     `PROPOSED_SYSTEM_ARCHITECTURE.md`).
   * **Anything that assumes more than one person is out of scope**: sharing, roles,
     permissions, per-user settings, invitations.
   If this is ever revisited, the path is still additive — `user_id` with a default on the
   three tables, scoped inside `db.py` — but it must not be built speculatively now.
2. **Where will the backend run** — the desktop that has the data today, a home server, or a
   cloud host? This decides the TLS and backup design.
3. **Does the mobile app need offline writes**, or is read-only-when-away acceptable for v1?
   Offline writes require `created_at`/`updated_at` (D7) and a client queue; read-only is
   substantially less work.
4. **Should the web dashboard migrate to the v1 API?** Not required — it works as server-rendered
   HTML, and the brief says retain it. Recommendation: leave it, and reconsider only if
   duplicated effort becomes real.
5. **Currency** (D6): confirm single-currency for now.
