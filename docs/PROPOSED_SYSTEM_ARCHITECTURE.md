# Proposed System Architecture

**Status:** proposal for review — **nothing in this document has been implemented**
**Date:** 2026-11-25 · **Baseline commit:** `9437392`
**Companion documents:** `PHASE_1_PROJECT_ASSESSMENT.md` (F1–F3),
`EXISTING_DATABASE_ASSESSMENT.md` (D1–D10), `EXISTING_FEATURES_INVENTORY.md` (S1–S27)

---

## 1. Objective and guiding constraint

Evolve LifePilot-Finance into a multi-platform system — Python backend, retained web frontend,
new Flutter mobile app, one database, one set of financial rules — **without rewriting what
already works.**

The architecture below is shaped by one finding from the assessment: the existing domain layer
(`money.py`, `models.py`, `db.py`, `categorize.py`, `importers.py`, `reports.py`) imports nothing
but the standard library and itself. It has no idea a web server exists. That means the target
architecture is reached by **adding an interface, not by restructuring the application.**

---

## 2. Target architecture

```
        ┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
        │  Flutter mobile    │   │  Web browser       │   │  Terminal          │
        │  Android / iOS     │   │                    │   │                    │
        │  NEW               │   │  RETAINED          │   │  RETAINED          │
        └─────────┬──────────┘   └─────────┬──────────┘   └─────────┬──────────┘
                  │ HTTPS/JSON              │ HTML over HTTP          │ in-process
                  │                         │                         │
        ┌─────────▼─────────────────────────▼─────────┐   ┌───────────▼────────┐
        │  INTERFACE LAYER                             │   │  cli.py            │
        │                                              │   │  (argparse)        │
        │  ┌────────────────────┐ ┌─────────────────┐  │   │  RETAINED          │
        │  │ api/  (NEW)        │ │ web.py +        │  │   └───────────┬────────┘
        │  │ FastAPI, REST v1   │ │ render.py       │  │               │
        │  │ auth, validation,  │ │ server-rendered │  │               │
        │  │ OpenAPI schema     │ │ HTML — RETAINED │  │               │
        │  └─────────┬──────────┘ └────────┬────────┘  │               │
        └────────────┼─────────────────────┼───────────┘               │
                     │                     │                           │
        ┌────────────▼─────────────────────▼───────────────────────────▼────────┐
        │  SERVICE LAYER  (thin, NEW — relocation only, no new logic)           │
        │  services.py : month/year resolution, available months,               │
        │                category list, import-from-stream, payload assembly    │
        │  Everything here is moved out of web.py so HTML and JSON share it.    │
        └────────────────────────────┬──────────────────────────────────────────┘
                                     │
        ┌────────────────────────────▼──────────────────────────────────────────┐
        │  DOMAIN LAYER  (UNCHANGED — the single financial engine)              │
        │  reports.py    all aggregation, transfer exclusion, budget maths       │
        │  categorize.py rule matching and precedence                           │
        │  importers.py  CSV parsing and column detection                       │
        └────────────────────────────┬──────────────────────────────────────────┘
                                     │
        ┌────────────────────────────▼──────────────────────────────────────────┐
        │  PERSISTENCE  (UNCHANGED interface, additive internals)               │
        │  db.py  all SQL · migration runner added · WAL enabled                │
        └────────────────────────────┬──────────────────────────────────────────┘
                                     │
        ┌────────────────────────────▼──────────────────────────────────────────┐
        │  PRIMITIVES  (UNCHANGED)                                              │
        │  models.py  dataclasses      money.py  integer cents, no floats       │
        └────────────────────────────┬──────────────────────────────────────────┘
                                     │
        ┌────────────────────────────▼──────────────────────────────────────────┐
        │  SQLite — one file, one schema  (data/finance.db)                     │
        └───────────────────────────────────────────────────────────────────────┘
```

### What changes, what does not

| Component | Phase 2 treatment |
|---|---|
| `money.py`, `models.py` | **No change** |
| `reports.py`, `categorize.py`, `importers.py` | **No change** to existing functions. `importers` gains a stream overload (S8); `reports` receives relocated helpers (S21, S24, S25) |
| `db.py` | **Additive only** — migration runner (D1), WAL (D2), `busy_timeout` (D3), `get_transaction` (S2), `set_notes` (S7), `list_categories` (S23), `offset` on `list_transactions` |
| `cli.py` | **No change** — continues to call the domain layer directly |
| `web.py`, `render.py`, `static/*` | **Retained.** `web.py` delegates its gather logic to the service layer instead of holding it |
| `api/` | **New** package — the only new interface |
| Flutter app | **New** — a client, never a calculation engine |
| Database file | **Never reset, never migrated destructively** |

---

## 3. The four architectural rules

These exist because they are the rules that, if broken, produce the failure modes the brief is
trying to prevent.

### Rule 1 — One financial engine, in Python

**All aggregation, categorization, and budget evaluation happens in `reports.py` and
`categorize.py`. No client recomputes a total.**

Why this is not negotiable: the assessment found at least six business rules embedded in the
report functions — transfers excluded by default, expenses returned as positive magnitudes while
net keeps its sign, budgets covering expenses only and scoped to a calendar month, months without
records returned as `None` rather than zero, savings rate guarded at zero income, and ties in rule
precedence broken by insertion order. A Dart re-implementation would have to reproduce every one
of them and then stay in step forever. It will not.

Practical test: **if a number appears on a Flutter screen, an API response contained that number.**
Flutter may format, sort, and lay out. It may not add, subtract, or divide money.

### Rule 2 — Integer cents cross every boundary

Storage, domain, API JSON, and Dart all carry **integer cents**. No float, no `Decimal` string,
no pre-formatted currency string as the only representation.

- API responses use `*_cents` integer fields (`income_cents`, not `income`).
- Dart models use `int`. Never `double` — IEEE-754 cannot represent `0.10` exactly, and a
  rounding drift in a ledger is a defect, not a cosmetic issue.
- Formatting happens at the edge: `money.format_money` in Python, an equivalent display-only
  helper in Dart.

### Rule 3 — The domain layer stays framework-free

`reports.py`, `categorize.py`, `importers.py`, `db.py`, `models.py`, `money.py` must continue to
import **only the standard library and each other.** No FastAPI import, no pydantic import, no
request object reaching them.

This is what keeps the CLI working, keeps the 172 existing tests valid as a regression gate, and
keeps the API replaceable. Request validation and serialization belong in `api/schemas.py`;
translation between HTTP and domain objects belongs in `api/routers/`.

### Rule 4 — Database changes are additive and versioned

No `DROP`, no column type change, no rename of an existing column. New columns arrive with a
`DEFAULT`; new tables and indexes are plain additions. Every change goes through the migration
runner keyed on `PRAGMA user_version`, and the upgrade path is tested against a database built by
the previous version (D1).

---

## 4. Component responsibilities

| Component | Owns | Must not |
|---|---|---|
| `api/` | HTTP concerns: routing, auth, request validation, serialization, status codes, OpenAPI | Contain any arithmetic on money; query SQLite directly |
| `services.py` | Orchestration shared by interfaces: resolving a requested month/year with fallback, assembling multi-part payloads, wrapping an upload into an import | Introduce new financial rules |
| `reports.py` | Every aggregation and derived financial figure | Know about HTTP or HTML |
| `categorize.py` | Rule precedence and matching | Know about HTTP or HTML |
| `importers.py` | Parsing external files into `Transaction` objects | Write to the database |
| `db.py` | All SQL, schema, migrations, connection lifecycle | Aggregate or categorize |
| `web.py` + `render.py` | Server-rendered HTML for the browser | Become a JSON API; duplicate service logic |
| `cli.py` | Terminal interface | Be the only write path (after Phase 2) |
| Flutter app | Presentation, navigation, local caching, offline queueing | Compute financial figures |

---

## 5. Deployment topologies

The architecture must work in three situations without code changes — only configuration.

### 5.1 Local only (today, and the default)

```
  ┌───────────────────────── one machine ─────────────────────────┐
  │  terminal → cli.py ─┐                                          │
  │                     ├→ domain → SQLite                         │
  │  browser → web.py ──┘                                          │
  └────────────────────────────────────────────────────────────────┘
```
No API, no network exposure. This must keep working exactly as it does now.

### 5.2 Home server — **the chosen deployment (decided 2026-11-26)**

```
  ┌──────── home server / desktop ────────┐        ┌──────────────┐
  │  reverse proxy (TLS)                   │        │  phone       │
  │        │                               │        │  Flutter app │
  │        ├→ api/ (FastAPI, uvicorn) ─┐   │◀──────▶│              │
  │        └→ web.py ──────────────────┤   │ HTTPS  └──────────────┘
  │                                    ├→ domain → SQLite          │
  │  terminal → cli.py ────────────────┘   │                        │
  └────────────────────────────────────────┘
```

Requirements this introduces:
- **TLS is mandatory** once a bearer token crosses a network. Terminate at the proxy
  (Caddy/nginx); the application speaks plain HTTP on loopback behind it.
- **Token authentication** on every API request (F2).
- **WAL mode** so the browser and the phone can read while a write is in flight (D2).
- **The home server owns the database.** `data/finance.db` lives there and nowhere else; the
  desktop CLI becomes a client of the same machine, or is used over SSH. Two copies of the
  file on two machines is the one topology to avoid — SQLite has no replication, and the
  fingerprint deduplication only protects against duplicate *rows*, not divergent files.

#### The unresolved half: reaching it from outside the house

A home server answers *where the data lives*. It does not answer **how the phone reaches it
when the user is not at home**, and that is the question that actually shapes the security
design. The realistic options, in the order I would consider them:

| Option | TLS story | Exposure | Verdict |
|---|---|---|---|
| **VPN (WireGuard / Tailscale)** | A private cert, or plain HTTP inside the tunnel | Nothing published to the internet | **Recommended.** The phone joins the home network from anywhere; no inbound port, no public DNS, no certificate renewal on a dynamic IP. The smallest attack surface by a wide margin |
| **Port-forward + dynamic DNS + Let's Encrypt** | Public cert, auto-renewed | The API is on the public internet, protected by one bearer token | Workable, but it puts a single-token financial API on the open internet and needs DNS-01 renewal if inbound :80 is unavailable |
| **LAN-only** | Private cert or plain HTTP on the LAN | None | Simplest, but the app only works at home, which defeats much of the point of a phone client |

**This needs an answer before the auth work in Phase 03 step 3**, because it decides whether
the token is the only thing between the internet and the ledger (port-forward) or a second
layer behind a tunnel (VPN).

### 5.3 Single-user cloud host (optional, later)

Same code, with the database on persistent storage and the proxy public. At this point revisit:
backups, a stronger auth story than a static token, and whether SQLite or Postgres fits — see §7.

---

## 6. Request lifecycle

**Mobile read** — `GET /api/v1/reports/year?year=2026`
```
Flutter repository
  → HTTPS + Bearer token
  → reverse proxy (TLS termination)
  → FastAPI router
      · auth dependency verifies the token
      · query params validated by the schema
      · connection dependency opens one SQLite connection
  → services.resolve_year(conn, requested)        (relocated from web.py)
  → reports.month_series / yearly_summaries / month_average / by_category
  → api/schemas serializes integer cents, gaps as null
  → JSON
  → Dart DTO → domain model → Riverpod state → widget
```

**Mobile write** — `POST /api/v1/transactions`
```
Flutter form (amount entered as text)
  → repository sends { date, description, amount_cents, account, notes }
  → FastAPI validates shape and types
  → categorize.categorize(description, db.list_rules(conn))   if no category given
  → db.add_transaction(conn, Transaction(...))
      · Transaction.fingerprint() computed in the domain layer
      · UNIQUE(fingerprint) + INSERT OR IGNORE
  → inserted id  →  201 Created
     or None     →  409 Conflict with the existing transaction's id
```

The 409 path is what makes an offline write queue safe to retry: replaying the same transaction
is a no-op rather than a duplicate.

---

## 7. Database strategy

| Question | Decision | Reasoning |
|---|---|---|
| Keep SQLite? | **Yes** | One user, interactive write volume, and the whole dataset is a few thousand rows. The assessment found the schema and indexes sound (D10) |
| WAL? | **Yes, Phase 2 Step 1** | Concurrent browser + phone readers during a write (D2) |
| Busy timeout? | **Yes, 5s** | Brief contention should retry, not error (D3) |
| Connection pooling? | **No** | Connection-per-request is already the pattern and is correct for SQLite |
| ORM? | **No** | `db.py` is 217 lines of clear SQL with full test coverage. An ORM would be a rewrite of working code for no gain |
| Postgres? | **No** | Multi-user is not coming (decided 2026-11-26), which removes the only argument for it. The migration path exists if that changes |
| Multi-user `user_id`? | **No — single user decided 2026-11-26** | The product is single-user, so no `user_id`, no query scoping, no identity migration. The additive path remains available if that ever changes, but is not to be built speculatively (D4) |
| Sync columns? | **Add `created_at` / `updated_at` when offline sync is built** | Required for `?since=` incremental sync (D7) |

### Backup — code resolved, data specified but not implemented

F1 is **resolved as of 2026-11-25**: a reachable remote is configured
(`clinemaster/PesPlan-Finance`) and the history is pushed, so the code now has an off-machine
copy. The data half is not:

- **Code:** working remote + `git push`. ✅ Done.
- **Data:** the database is correctly git-ignored (D9), which means **git will never back up
  financial data.** Pushing code is not a data backup.

Now that the deployment is settled (2026-11-26: home server), the data backup can be specified
rather than deferred. The shape it should take:

1. **A consistent snapshot, not a file copy.** `sqlite3 data/finance.db "VACUUM INTO
   '/backups/finance-$(date +%F).db'"` — safe while the server is running, and it compacts.
   Copying the file directly while a write is in flight can capture a torn database.
2. **Off the machine.** A home server is one disk in one building; a snapshot sitting beside
   the original survives neither a drive failure nor a theft. It must leave the host.
3. **Scheduled and verified.** A nightly `cron`/systemd timer, plus a periodic restore test —
   an unverified backup is a belief, not a backup.
4. **Encrypted at rest** if it leaves the home network, because the contents are a complete
   record of someone's finances.

This remains **outstanding**; it is now a specification waiting to be implemented rather than
an open design question.

---

## 8. Security architecture

| Concern | Today | Proposed |
|---|---|---|
| Transport | Plain HTTP on loopback | TLS at the proxy for anything off-machine; API binds loopback only. Home server decided 2026-11-26; how the phone reaches it from outside (VPN vs port-forward) is still open — see §5.2 |
| Authentication | **None** (F2) | Bearer token required on all `/api/v1/*`; token from env/secret file, never committed; compared with `secrets.compare_digest` |
| Mobile token storage | — | OS keystore via `flutter_secure_storage`; never in `SharedPreferences` or source |
| Authorization | None needed (single user, decided 2026-11-26) | Authentication alone is sufficient: one token, one person. No roles, no per-row scoping |
| Input validation | argparse + CSV parsing | Schema validation at the API edge; domain validators (`parse_money`, `parse_date`) retained as the second line |
| Output escaping | `render.esc` on every value | Unchanged for HTML. JSON needs no escaping, but Flutter must treat `description` as untrusted text and never render it as markup |
| CSP | `default-src 'none'` | Unchanged — the existing policy is strong |
| Rate limiting | None | Modest per-token limit at the proxy once exposed |
| Secrets in repo | None | Keep it that way: `.env` git-ignored, config via environment |
| Audit | None | Optional append-only log of API writes if it ever matters |

**Stated plainly:** the current design is safe *because* it is loopback-only and unauthenticated —
those two facts depend on each other. Adding a phone removes the first, so the second must be
fixed in the same step. Never ship `--host 0.0.0.0` without token auth and TLS.

---

## 9. Testing strategy

| Layer | Approach | Status |
|---|---|---|
| Domain | The existing 172 tests | **Exists.** Treat as an immovable regression gate |
| Migrations | Build a v1 file, upgrade, assert data survives | To add (D1) |
| Service layer | Unit tests on relocated functions | To add, with the relocation |
| API | `TestClient` per endpoint: happy path, validation failure, auth failure, 404, 409 | To add |
| Contract | Assert the generated OpenAPI schema against a committed snapshot, so a breaking change fails CI | To add |
| Flutter | Unit (repositories with a mocked client), widget, golden | To add |
| End-to-end | Seed a database → start the API → drive the Flutter app in integration test mode | Optional |
| Coverage | `pytest-cov` with a floor on the domain layer | To add |

The contract test is the one that protects the Flutter app: a renamed JSON field is otherwise
invisible until a phone breaks in the field.

---

## 10. Repository layout after Phase 2

```
LifePilot-Finance/
├── src/lifepilot/
│   ├── money.py  models.py  db.py                 UNCHANGED (db.py additive only)
│   ├── categorize.py  importers.py  reports.py    UNCHANGED
│   ├── services.py                                NEW — relocated orchestration
│   ├── cli.py                                     UNCHANGED
│   ├── web.py  render.py  static/                 RETAINED
│   └── api/                                       NEW
│       ├── app.py            FastAPI application factory
│       ├── deps.py           connection + auth dependencies
│       ├── schemas.py        request/response models
│       └── routers/          transactions, reports, budgets, rules, meta
├── mobile/                                        NEW — Flutter app
│   └── (see FLUTTER_ARCHITECTURE.md)
├── docs/                                          this assessment
├── tests/                                         172 existing + new API tests
├── data/                                          git-ignored database
└── pyproject.toml                                 api extra added
```

### Dependency policy

The project's zero-dependency property is a genuine asset — it is why `pip install -e .` is all
the setup the CLI and web UI need. Preserve it by making the API an **optional extra**:

```toml
[project]
dependencies = []                      # core, CLI and web UI stay dependency-free

[project.optional-dependencies]
dev = ["pytest>=8.0"]
api = ["fastapi>=0.115", "uvicorn[standard]>=0.30"]
```

`pip install -e .` → CLI + web dashboard, no dependencies.
`pip install -e ".[api]"` → adds the REST API.

`src/lifepilot/api/` must therefore be imported lazily (from `cli.py`'s `serve-api` command, or
by uvicorn directly) so that a core-only install never tries to import FastAPI.

---

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Financial logic duplicated in Dart** | Two engines drift; numbers disagree between phone and web | Rule 1, enforced in code review. No arithmetic on money in Dart |
| **Floats in the JSON contract** | Rounding drift in a ledger | Rule 2. Contract test asserts `*_cents` fields are integers |
| **Schema change without a migration** | A user's database breaks or silently loses a column | Rule 4 + migration runner before any change (D1) |
| **API exposed without auth** | Financial data readable by anyone on the network | Token auth lands in the same step as the first non-loopback bind (F2) |
| **Work lost — no backup** | Total loss of the project | Code: remote configured and pushed (F1). ✅ **Closed.** Data: `data/finance.db` is git-ignored and has no backup routine. **Open** |
| **Web frontend rewritten "while we're here"** | Loses a tested, accessible, dependency-free UI | Explicitly out of scope; `web.py`/`render.py` are retained |
| **Service relocation breaks the dashboard** | Regression in working software | The 172 tests must pass untouched after every relocation step |
| **Scope creep into multi-user** | Large cost for a single-user product | ✅ **Settled 2026-11-26: single user.** Treat sharing, roles and per-user data as out of scope unless the decision is formally revisited |

---

## 12. Alignment with the preservation requirements

| Requirement from the brief | How this architecture honours it |
|---|---|
| Do not delete existing Python modules | Every module is retained; only additions proposed |
| Do not replace existing business logic | Rule 1 and Rule 3; `reports.py` and `categorize.py` are unchanged |
| Do not delete or reset the database | No destructive operation anywhere; Rule 4 |
| Do not remove transaction records | No delete path introduced beyond the existing per-id one |
| Do not replace the existing web frontend | `web.py`, `render.py`, `app.css`, `app.js` retained as the browser interface |
| Do not introduce breaking database changes | Rule 4: additive, defaulted, versioned, tested |
| Do not rewrite functionality without understanding it | This assessment is that understanding; relocations are mechanical and test-gated |
| No second calculation engine in Flutter | Rule 1 and §4 responsibilities table |
