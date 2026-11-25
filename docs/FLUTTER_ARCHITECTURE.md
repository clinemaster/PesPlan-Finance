# Flutter Architecture Proposal

**Status:** proposal for review — **no Flutter project has been created**
**Date:** 2026-11-25 · **Baseline commit:** `9437392`
**Companion documents:** `PROPOSED_SYSTEM_ARCHITECTURE.md` (Rules 1–4),
`API_DESIGN_PROPOSAL.md` (endpoints and contracts)

---

## 1. The governing constraint

> **The Flutter app is a presentation client. It contains no financial engine.**

Every monetary figure shown in the app comes from an API response. Dart may format, sort,
filter, group for layout, and cache. Dart may **not** sum amounts, compute a net, derive a
savings rate, evaluate a budget, decide whether a transaction is a transfer, or categorize a
description.

This is not stylistic caution. The assessment found that the Python reporting layer encodes at
least six rules that are invisible from a JSON payload alone:

1. Transfers are excluded from every total by default.
2. Report `expense_cents` is a positive magnitude while stored amounts are negative and
   `net_cents` is signed.
3. Budgets cover expenses only, per calendar month.
4. Months with no records are `null`, not zero — including future months.
5. Savings rate is defined as `0.0` when income is `≤ 0`.
6. Rule precedence is `(priority ASC, id ASC)` — insertion order breaks ties.

A Dart re-implementation would need all six, forever, in step with the Python. It will not stay
in step. So the architecture below makes the correct thing the easy thing: there is no place in
the layering where client-side money arithmetic naturally belongs.

**Review heuristic:** a Dart file that contains `+`, `-`, or `/` applied to a `*Cents` value, or
a `fold`/`reduce` over amounts, is a defect unless it is laying out a chart bar.

---

## 2. Technology selection

| Concern | Choice | Why |
|---|---|---|
| State management | **Riverpod** (`flutter_riverpod` + `riverpod_annotation`) | Compile-safe dependency injection without `BuildContext`; `AsyncValue` models loading/data/error as one type, which is exactly the shape of every screen here; testable without a widget tree |
| Routing | **go_router** | Declarative, URL-shaped routes that mirror the existing web paths; typed route helpers; deep links for free |
| HTTP | **dio** | Interceptors for the bearer token, retry and logging in one place; good timeout and cancellation control |
| API client | **Generated from OpenAPI** (`openapi-generator`), wrapped by hand-written repositories | The contract is generated, not transcribed — removes the main drift risk between Python and Dart |
| Models | **freezed** + **json_serializable** | Immutable data classes, exhaustive `when`, generated `fromJson`. `copyWith` without boilerplate |
| Secure storage | **flutter_secure_storage** | API token in the iOS Keychain / Android Keystore. Never `SharedPreferences` |
| Local cache | **drift** (SQLite) | Read-through cache of the last successful payloads so the app opens with content offline. Mirrors the server's storage model |
| Preferences | **shared_preferences** | Non-sensitive only: theme, last-viewed month |
| Charts | **fl_chart**, or custom `CustomPainter` | Both acceptable. Charts receive pre-computed series and plot them |
| Formatting | **intl** | Dates and number grouping. Money formatting is a thin local helper over integer cents |
| Testing | `flutter_test`, `mocktail`, `golden_toolkit`, `integration_test` | Unit, widget, golden, end-to-end |

### Deliberately rejected

| Option | Reason |
|---|---|
| BLoC | Workable, but more ceremony per screen than these mostly-read screens justify |
| `setState` only | Will not survive shared cross-screen state (selected month, auth) |
| Hand-written API client | The error this architecture most needs to prevent |
| `sqflite` raw | `drift` gives type-safe queries for the same dependency weight |
| A Dart "finance" package shared with the backend | Impossible and undesirable — the engine is Python, and duplicating it is the prohibited outcome |

---

## 3. Project structure

Feature-first, with a conventional three-layer split inside each feature. Features map to the
existing web pages, so the two frontends stay conceptually aligned.

```
mobile/
├── pubspec.yaml
├── analysis_options.yaml                  strict lints (see §10)
├── openapi/
│   └── lifepilot.v1.json                  committed schema snapshot; regeneration input
├── lib/
│   ├── main.dart                          bootstrap: ProviderScope + env assertion
│   ├── app.dart                           MaterialApp.router, theming
│   │
│   ├── core/
│   │   ├── config/
│   │   │   ├── env.dart                   compile-time config from --dart-define
│   │   │   └── flavor.dart                dev / staging / prod
│   │   ├── network/
│   │   │   ├── dio_client.dart            base URL, timeouts, interceptors
│   │   │   ├── auth_interceptor.dart      attaches the bearer token
│   │   │   ├── api_exception.dart         maps the server error envelope to typed failures
│   │   │   └── connectivity.dart          online/offline signal
│   │   ├── money/
│   │   │   ├── money.dart                 Money value type over int cents — FORMAT ONLY
│   │   │   └── money_formatter.dart       grouping, sign, optional symbol
│   │   ├── storage/
│   │   │   ├── secure_store.dart          token read/write
│   │   │   └── cache_db.dart              drift database for cached payloads
│   │   ├── router/
│   │   │   ├── app_router.dart            go_router configuration
│   │   │   └── routes.dart                typed route constants
│   │   ├── theme/
│   │   │   ├── app_theme.dart             light + dark ThemeData
│   │   │   └── chart_palette.dart         mirrors static/app.css tokens
│   │   └── widgets/                       StatTile, MoneyText, AsyncValueView,
│   │                                      EmptyState, ErrorRetry, TableView
│   │
│   ├── features/
│   │   ├── auth/                          pairing / token entry
│   │   │   ├── data/      auth_repository.dart
│   │   │   ├── domain/    auth_state.dart
│   │   │   └── presentation/ pairing_screen.dart, providers.dart
│   │   ├── dashboard/                     ← mirrors web "/"
│   │   │   ├── data/      dashboard_repository.dart, dashboard_dto.dart
│   │   │   ├── domain/    dashboard_summary.dart, category_total.dart
│   │   │   └── presentation/ dashboard_screen.dart, widgets/, providers.dart
│   │   ├── year/                          ← mirrors web "/year"
│   │   ├── transactions/                  ← mirrors web "/transactions"
│   │   │   └── presentation/ list_screen.dart, detail_screen.dart,
│   │   │                     add_edit_screen.dart
│   │   ├── budgets/
│   │   └── settings/                      theme, server, token, cache
│   │
│   └── generated/
│       └── api/                           openapi-generator output — NEVER edited by hand
└── test/
    ├── unit/            repositories, Money formatting, DTO mapping
    ├── widget/          screens against fake providers
    ├── golden/          dashboard and year screens, light and dark
    └── integration/     against a seeded local API
```

### Layer contract per feature

| Layer | Contains | Depends on |
|---|---|---|
| `data/` | DTOs (generated or `freezed`), repository implementation, cache read/write | `core/network`, `core/storage`, `generated/api` |
| `domain/` | Immutable models the UI consumes, mapped from DTOs | nothing (pure Dart) |
| `presentation/` | Screens, widgets, Riverpod providers | `domain/`, `core/widgets` |

DTOs never reach a widget. The mapping step in `data/` is where the API contract's conventions
(positive expense magnitudes, `null` months) are translated once into explicit domain types, so
no widget has to remember them.

---

## 4. State management

### Provider taxonomy

```dart
// Infrastructure — overridden wholesale in tests
final dioProvider           = Provider<Dio>(...);
final apiClientProvider     = Provider<LifepilotApi>(...);
final secureStoreProvider   = Provider<SecureStore>(...);
final cacheDbProvider       = Provider<CacheDb>(...);

// Session
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(...);

// Cross-feature selection — the mobile equivalent of the web's single filter row
final selectedMonthProvider = StateProvider<String>((ref) => currentMonthKey());
final selectedYearProvider  = StateProvider<int>((ref) => DateTime.now().year);

// Feature data — refetches automatically when the selection changes
final dashboardProvider =
    AsyncNotifierProvider.family<DashboardController, Dashboard, String>(...);
final yearReportProvider =
    AsyncNotifierProvider.family<YearController, YearReport, int>(...);
```

### Principles

1. **One `AsyncNotifier` per screen-worth of data**, keyed by its filter via `.family`. Changing
   the month invalidates exactly one provider; Riverpod refetches and the UI shows the previous
   value until new data lands.
2. **`AsyncValue` is the only loading model.** Screens render through a shared `AsyncValueView`
   that handles loading, error-with-retry, and empty states identically everywhere.
3. **No business logic in notifiers.** A notifier calls a repository and holds the result. If a
   notifier starts summing things, the needed figure is missing from the API — add it server-side
   (Rule 1).
4. **Cache-then-network.** On subscribe: emit the cached payload if present, fetch, replace.
   Offline fetch failure keeps the cached value and surfaces a non-blocking "showing saved data"
   banner rather than an error screen.
5. **Keep the frame on refresh.** Hold the previous render while refetching — no skeleton flash,
   matching the web dashboard's behaviour.

---

## 5. Routing

```dart
final router = GoRouter(
  initialLocation: Routes.dashboard,
  refreshListenable: authChangeNotifier,
  redirect: (context, state) =>
      ref.read(authControllerProvider).isPaired ? null : Routes.pairing,
  routes: [
    GoRoute(path: Routes.pairing,  builder: ...),            // '/pairing'
    ShellRoute(                                              // bottom navigation
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: Routes.dashboard,    builder: ...),    // '/'
        GoRoute(path: Routes.year,         builder: ...),    // '/year'
        GoRoute(path: Routes.transactions, builder: ...,     // '/transactions'
          routes: [
            GoRoute(path: 'new', builder: ...),              // '/transactions/new'
            GoRoute(path: ':id', builder: ...),              // '/transactions/42'
          ],
        ),
        GoRoute(path: Routes.budgets,  builder: ...),        // '/budgets'
        GoRoute(path: Routes.settings, builder: ...),        // '/settings'
      ],
    ),
  ],
);
```

- **Paths mirror the web UI** (`/`, `/year`, `/transactions`) so the two frontends share a mental
  model and deep links are obvious.
- **`ShellRoute`** provides persistent bottom navigation: Dashboard · Year · Transactions ·
  Budgets.
- **Auth redirect** is centralised; no screen checks pairing state itself.
- Filters (`month`, `year`) live in Riverpod rather than the URL, because they are session state
  rather than addressable locations — with one exception: `/transactions/:id` is addressable, for
  notification deep links later.

---

## 6. API service architecture

```
Widget
  └─ ref.watch(dashboardProvider(month))
       └─ DashboardController (AsyncNotifier)
            └─ DashboardRepository                     ← the only layer that knows about JSON
                 ├─ LifepilotApi (generated)  ──▶ Dio ──▶ HTTPS ──▶ FastAPI
                 └─ CacheDb (drift)                    ← read-through cache
```

### Repository responsibilities

```dart
class DashboardRepository {
  Future<Dashboard> fetch(String month) async {
    try {
      final dto = await _api.getDashboard(month: month);   // generated client
      await _cache.saveDashboard(month, dto);
      return dto.toDomain();                               // DTO → domain mapping
    } on DioException catch (e) {
      final cached = await _cache.readDashboard(month);
      if (cached != null) return cached.toDomain().markStale();
      throw ApiException.from(e);                          // typed failure
    }
  }
}
```

Rules:
- **Repositories are the only place DTOs exist.** They return domain models.
- **No repository performs arithmetic on money.** It maps and caches.
- **Failures are typed** — `ApiException.unauthorized` / `.notFound` / `.conflict` /
  `.network` / `.server`, decoded from the server's `{ "error": { code, message } }` envelope —
  so the UI can react specifically (401 → re-pair) instead of showing a raw string.

### Client generation workflow

```bash
# 1. Export the schema from the running backend
curl -s localhost:8000/openapi.json > mobile/openapi/lifepilot.v1.json

# 2. Regenerate the Dart client
openapi-generator generate -i mobile/openapi/lifepilot.v1.json \
  -g dart-dio -o mobile/lib/generated/api

# 3. Build freezed/json_serializable output
dart run build_runner build --delete-conflicting-outputs
```

The schema snapshot is **committed**, so a backend change that alters the contract shows up as a
reviewable diff in the mobile repo rather than as a runtime failure on a phone.

### Money handling in Dart — the critical detail

```dart
@immutable
class Money {
  const Money(this.cents);
  final int cents;                 // int, never double. IEEE-754 cannot hold 0.10 exactly.

  factory Money.fromJson(int cents) => Money(cents);

  bool get isExpense => cents < 0;

  /// Display only. There is deliberately no +, -, * or / on this type:
  /// every total the app shows is computed by the Python backend.
  String format({String symbol = ''}) { ... }
}
```

Omitting arithmetic operators from `Money` is the enforcement mechanism for Rule 1 — a developer
who tries to total a list of transactions client-side finds no API to do it with.

Input handling runs the other way: an amount typed as text is sent as `amount_cents`, converted
once by a parser that mirrors `money.parse_money` semantics (reject junk, round half-up, accept
grouped digits). That is parsing, not calculation.

---

## 7. Environment configuration

No secrets in source. Compile-time configuration via `--dart-define`.

```dart
abstract final class Env {
  static const flavor  = String.fromEnvironment('FLAVOR',   defaultValue: 'dev');
  static const apiBase = String.fromEnvironment('API_BASE_URL');
  static const logHttp = bool.fromEnvironment('LOG_HTTP',   defaultValue: false);

  static void assertValid() {
    if (apiBase.isEmpty) {
      throw StateError('API_BASE_URL is required. Pass --dart-define=API_BASE_URL=…');
    }
    if (flavor == 'prod' && !apiBase.startsWith('https://')) {
      throw StateError('prod builds must use HTTPS: a bearer token over HTTP is unprotected');
    }
  }
}
```

The prod HTTPS assertion is a real safeguard, not ceremony — it makes the dangerous build fail at
startup instead of silently shipping a token in clear text.

| Flavor | API base | Notes |
|---|---|---|
| `dev` | `http://10.0.2.2:8000` (Android emulator) or `http://localhost:8000` (iOS simulator) | Plain HTTP is acceptable on loopback only |
| `staging` | `https://…` on the home server | Real TLS, real token |
| `prod` | `https://…` | HTTPS enforced at startup |

```bash
flutter run --dart-define=FLAVOR=dev \
            --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
            --dart-define=LOG_HTTP=true
```

Android emulator note: `10.0.2.2` is the host loopback. Also recall the backend binds
`127.0.0.1` by default — reaching it from a device requires an explicit bind plus token auth plus
TLS, together (F2).

**The API token is never a `--dart-define`.** It is entered or scanned once at pairing and stored
in the OS keystore.

---

## 8. Screens, mapped to existing functionality

| Screen | Endpoint | Shows |
|---|---|---|
| Pairing | `GET /api/v1/health` | Server URL + token entry (QR or paste), connection check |
| Dashboard | `GET /api/v1/reports/dashboard?month=` | Net hero figure, income/expenses/saved tiles, spending by category, 12-month trend, budget meters, recent transactions |
| Year | `GET /api/v1/reports/year?year=` | Spent-this-year hero, monthly spending with the average, year-over-year comparison, categories, all-years table |
| Transactions | `GET /api/v1/transactions?month=&category=&q=` | Paginated list, filters, search |
| Transaction detail | `GET /api/v1/transactions/{id}` | Full record; edit category and notes; delete |
| Add transaction | `POST /api/v1/transactions` · `POST /api/v1/rules/preview` | Amount, date, description, account; live category preview from the server |
| Budgets | `GET /api/v1/budgets` · `GET /api/v1/reports/budget` | Budget vs actual meters; create, edit, delete |
| Settings | — | Theme, server, token, cache clear, app version |

Two notes:

- **The dashboard uses one composite request** rather than six, because a phone on mobile data
  should paint a screen in one round trip.
- **Add-transaction shows the category the server will assign**, via `/rules/preview`. The client
  never evaluates rule precedence itself.

### Visual consistency with the web UI

Port the design tokens from `src/lifepilot/static/app.css` into `core/theme/`: the same surface
and ink colours, the same income-blue / spending-orange series convention, the same de-emphasis
gray for prior-year context, and the same status colours paired with an icon and words rather
than colour alone. Charts should carry a table view, as the web charts do, so no value is
reachable only by touch-and-hold.

---

## 9. Offline strategy

Scope decision needed before implementation (open question 3 in `API_DESIGN_PROPOSAL.md`).

**Tier 1 — offline reads (recommended for v1)**
Cache the last successful payload per month/year in drift. On launch, show cached data with a
"showing saved data" banner, then refresh. Low complexity, covers the realistic case of opening
the app away from home.

**Tier 2 — offline writes (later)**
Queue mutations locally and replay when connectivity returns. The server design already supports
this safely:

- `Transaction.fingerprint()` makes creation idempotent, so a replayed write cannot duplicate.
- A `409 Conflict` response means "already recorded" — the queue treats it as success and drops
  the item.
- Queue entries need a local id, the payload, attempt count, and last error, surfaced in the UI
  as pending items.

Tier 2 also needs `created_at` / `updated_at` columns server-side for `?since=` incremental sync
(D7). Those are additive but not yet present, which is why Tier 2 is explicitly later.

---

## 10. Quality gates

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  exclude:
    - lib/generated/**          # generated client is not hand-maintained
  errors:
    missing_required_param: error
    missing_return: error
linter:
  rules:
    always_declare_return_types: true
    prefer_const_constructors: true
    avoid_print: true
    require_trailing_commas: true
```

| Gate | Enforces |
|---|---|
| `dart analyze` clean, strict casts on | No implicit `dynamic` from JSON |
| `dart format` | Consistent diffs |
| Unit tests: repositories, `Money` formatting, DTO mapping | Contract translation is correct, including `null` months |
| Widget tests per screen against fake providers | Loading, error, empty and populated states all render |
| Golden tests: dashboard + year, light and dark | Visual regressions caught |
| Committed OpenAPI snapshot | Backend contract changes are visible in review |
| **Custom review check:** no arithmetic operator applied to a `*Cents` value or `Money` outside chart layout | **Rule 1** — the architecture's central invariant |

---

## 11. Build order

| Step | Deliverable | Depends on |
|---|---|---|
| 1 | Project scaffold, flavors, env assertions, theming, strict lints | — |
| 2 | Dio client, auth interceptor, secure store, pairing screen | API `/health` + token auth (API step 3) |
| 3 | Generated client from the committed OpenAPI snapshot | API read endpoints (API step 4) |
| 4 | Dashboard screen end to end — proves the whole contract on one screen | step 3 |
| 5 | Year, transactions list, transaction detail | step 4 |
| 6 | Offline read cache (drift) + stale-data banner | step 5 |
| 7 | Writes: add, edit category/notes, delete, budgets | API write endpoints (API step 5) |
| 8 | Golden tests, integration tests against a seeded API, release signing | step 7 |

**Step 4 is the milestone that matters.** One screen rendering real figures from the Python
engine proves the contract, the auth flow, the money representation, and the `null`-month
handling in a single stroke. Do it before breadth.

---

## 12. Risks

| Risk | Mitigation |
|---|---|
| **Financial logic creeps into Dart** | `Money` has no arithmetic operators; review check in §10; missing figures get added to the API instead |
| **Floats from JSON** | Integer `*_cents` contract; strict casts; DTO mapping tests |
| **Contract drift between Python and Dart** | Generated client from a committed schema snapshot; backend contract test |
| **`null` months rendered as zero** | Domain model makes the gap explicit (`MonthEntry?`), with a mapping test |
| **Token leaked into source or logs** | Keystore only; never a `--dart-define`; HTTP logging off in prod builds |
| **Plain-HTTP production build** | Startup assertion fails the build at runtime |
| **Emulator cannot reach the backend** | Documented `10.0.2.2` and the loopback-bind consequence |
| **Scope creep into a full offline-first app** | Tier 1 only for v1; Tier 2 gated on a product decision and server sync columns |
