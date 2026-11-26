# LifePilot Finance — Mobile App

The Flutter client for LifePilot Finance. Built in phases:

| Phase | Delivers | State |
|---|---|---|
| 02 | Design system — tokens, theme, components | done |
| 03 | Welcome, mock Google sign-in, onboarding | done |
| 04 | Navigation shell and dashboard | done |
| 05 | Transactions — list, search, filter, add, edit, delete | done |
| 06 | Reports — periods, breakdown, annual, year comparison | done |
| 07 | Budgets | not started |

**There is still no backend, no real authentication and no financial data.** Sign-in is a
mock that contacts no Google service, and every figure in the showcase is placeholder data.

---

## Running the app

```bash
cd mobile
flutter pub get
flutter run            # starts at the welcome screen
```

`main.dart` launches the real root widget and its router. After onboarding the app settles
into a five-tab shell — Home, Activity, Budgets, Goals, Assistant. Home and Activity are
built; Budgets, Goals and Assistant are placeholders that say which phase they arrive in.

The Phase 02 design system showcase is still available at `/showcase`, reachable from
Profile & settings, so the visual language stays reviewable without being what the app
opens on.

### Seeing the states that are hard to reach

Both controls are review affordances and go away with the mock data.

- **Sign-in cancelled / failed** — long-press the brand mark on the welcome screen and pick
  what the next attempt returns.
- **The empty dashboard** — Profile & settings → Review controls → *Show the empty
  dashboard*.

---

## Using the design system

One import gives a screen everything:

```dart
import 'package:lifepilot_finance/core/design_system/design_system.dart';
```

```dart
Widget build(BuildContext context) {
  return AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Groceries', style: AppTypography.titleCard.copyWith(
          color: context.finance.textPrimary,
        )),
        const SizedBox(height: AppSpacing.md),
        const MoneyText(Money(420000), size: MoneySize.large),
      ],
    ),
  );
}
```

### Three rules for every screen built on this

1. **No literal colours, text styles, radii or paddings.** Use the tokens. A screen that
   needs something the system lacks adds it to the system, so the next screen inherits it.
2. **No financial arithmetic in Dart.** Amounts arrive already computed from the backend;
   the UI formats them. `Money` has no `+` operator, on purpose.
3. **Prefer an existing component** over a bespoke widget.

---

## Layout

```
lib/
├── main.dart                        ProviderScope + LifePilotApp
├── app.dart                         MaterialApp.router, theme mode
├── core/
│   ├── router/
│   │   ├── routes.dart              every route path, as constants
│   │   └── app_router.dart          go_router + the session guard
│   ├── design_system/
│   │   ├── design_system.dart       the single barrel import
│   │   ├── tokens/
│   │   │   ├── app_colors.dart      every colour, with measured contrast ratios
│   │   │   ├── app_typography.dart  the type scale, incl. tabular amount styles
│   │   │   ├── app_spacing.dart     4pt grid
│   │   │   ├── app_shape.dart       radii, icon sizes, stroke widths
│   │   │   ├── app_elevation.dart   layered shadows
│   │   │   ├── app_motion.dart      durations and curves
│   │   │   └── app_icons.dart       one icon family, named by meaning
│   │   └── theme/
│   │       ├── app_theme.dart       light + dark ThemeData, component themes
│   │       ├── finance_colors.dart  ThemeExtension: finance semantics + chart palettes
│   │       └── context_ext.dart     context.colors / context.text / context.finance
│   ├── money/money.dart             Currency + Money (integer minor units, format only)
│   └── widgets/
│       ├── app_button.dart          AppButton (6 variants), AppIconButton
│       ├── app_card.dart            AppCard, SectionHeader, AppDivider, ChartContainer
│       ├── app_display.dart         MoneyText, badges, status, avatar, progress
│       ├── app_inputs.dart          text, amount, search, dropdown, date, currency
│       ├── app_states.dart          empty, error, loading, skeletons
│       ├── app_feedback.dart        dialog, bottom sheet, snackbar
│       ├── app_navigation.dart      AppTopBar, AppBottomNav
│       ├── finance_cards.dart       balance, summary, budget, transaction row
│       └── charts/charts.dart       line, bar, donut, category breakdown
├── features/
│   ├── onboarding/
│   │   ├── domain/                  AuthUser, AuthResult, AuthRepository,
│   │   │                            Country, AppLanguage, UserProfile,
│   │   │                            ProfileValidator — pure Dart, no widgets
│   │   ├── data/
│   │   │   └── mock_auth_repository.dart   the ONLY mock; replaced in Phase 12
│   │   └── presentation/
│   │       ├── providers/           AuthController, OnboardingController
│   │       ├── widgets/             brand mark, Google button + painted logo,
│   │       │                        onboarding scaffold and progress
│   │       └── screens/             welcome, profile, preferences, completion
│   ├── dashboard/
│   │   ├── domain/                  DashboardData and its parts, DashboardPeriod,
│   │   │                            greetingFor — every figure already computed
│   │   ├── data/
│   │   │   └── mock_dashboard_repository.dart   stands in for the reporting API
│   │   └── presentation/
│   │       ├── providers/           period, data, mock mode, injectable clock
│   │       ├── widgets/             header, period selector, summary, chart,
│   │       │                        budget, savings, activity, quick actions,
│   │       │                        empty state
│   │       └── screens/dashboard_screen.dart
│   ├── transactions/
│   │   ├── domain/                  Transaction, categories, filter, view,
│   │   │                            validator, date labels — pure Dart
│   │   ├── data/
│   │   │   └── mock_transaction_repository.dart   in-memory, plays the server
│   │   └── presentation/
│   │       ├── providers/           repository, filter, list, write actions
│   │       ├── widgets/             summary strip, filter sheet, detail
│   │       │                        sheet, category picker, type selector
│   │       └── screens/             list, add/edit form, edit loader
│   ├── reports/
│   │   ├── domain/                  ReportPeriod and its date maths,
│   │   │                            ReportData, comparison types
│   │   ├── data/
│   │   │   └── mock_report_repository.dart   derives reports from
│   │   │                            recorded transactions
│   │   └── presentation/            overview, annual report, comparison
│   ├── shell/presentation/          the five-tab frame
│   ├── settings/presentation/       profile, theme, review controls
│   └── placeholders/presentation/   honest "not built yet" screen
└── showcase/                        internal review screen, route /showcase
```

---

## The decisions worth knowing

### Colour is measured, not chosen by eye

Every token's contrast was computed, and three proposed values did not survive:

| Token | Measured on white | Outcome |
|---|---|---|
| `#94A3B8` muted | **2.56:1** | Below even the 3:1 non-text floor → kept only as `textDisabled` |
| `#16A34A` income | **3.30:1** | Fine as a mark, fails as text → split into `income` / `incomeText` |
| `#0D9488` savings | **3.74:1** | Same split |
| `#F59E0B` warning | **2.15:1** | Fails as an icon too → only valid as a fill behind dark ink |
| `#DC2626` expense | 4.83:1 on white but **4.41:1 on its own tint** | Needed `expenseText` `#B91C1C` |

Hence the rule: **a semantic colour has a `mark` value for fills and icons, and a `*Text`
value for anything read.** `test/accessibility_test.dart` enforces all of this.

### Chart palettes were validated, including their limits

The series palette passes a six-check colour audit (lightness band, chroma floor,
colour-vision separation, normal-vision separation, contrast) with worst adjacent-pair
CVD ΔE 11.3 against a ≥8 target.

**Donut charts are hard-capped at three colours.** With every segment compared against
every other, blue and purple measure ΔE 1.3 apart under deuteranopia — indistinguishable —
and no ordering of six hues clears the floor. A breakdown with more parts uses
`CategoryBreakdown` (one colour plus text) or folds its tail into "Other".

### Money

- Integer **minor units** everywhere, matching the backend's `*_cents` contract. No `double`.
- **TZS has no subunit**, so amounts render as `TSh 12,500`, never `TSh 12,500.00`.
- Amount styles use **tabular figures** so columns line up and a changing balance doesn't jitter.
- **Amounts scale down rather than truncate.** At a large text scale a label may ellipsise;
  a figure may not — `TSh 3,2…` destroys the only thing the user came for.

### Accessibility

- Every status is **colour + icon + words**. Never colour alone.
- Touch targets are **≥48dp** regardless of the glyph inside.
- Amounts announce as "85,400 TZS out", not a run of symbols.
- Every chart ships a **table view** through `ChartContainer`.
- Layouts reflow at **2× text scale** — there are tests that fail on overflow.

---

## Tests

```bash
flutter analyze                      # 0 issues
flutter test                         # 126 tests
flutter test --update-goldens test/golden   # regenerate the review screenshots
```

| File | What it covers |
|---|---|
| `test/money_test.dart` | Formatting, TZS zero-decimal, grouping, abbreviation, semantics |
| `test/theme_test.dart` | Theme registration, palette and token invariants, component themes |
| `test/widgets_test.dart` | Every component's behaviour, in light and dark |
| `test/accessibility_test.dart` | Computed WCAG contrast, touch targets, labels, 2× text |
| `test/golden/` | Screenshots of all five showcase tabs, both themes, plus 1.6× text |
| `test/onboarding/profile_validator_test.dart` | Name and optional-phone rules |
| `test/onboarding/mock_auth_repository_test.dart` | The three sign-in outcomes, country/currency invariants, `UserProfile` |
| `test/onboarding/onboarding_controller_test.dart` | Both controllers, without a widget tree |
| `test/onboarding/welcome_screen_test.dart` | Welcome screen and its loading, cancelled and error states |
| `test/onboarding/onboarding_flow_test.dart` | The whole flow through the real router, including back navigation |

| `test/dashboard/mock_dashboard_repository_test.dart` | That the mock's figures add up — net, remaining, every ratio |
| `test/dashboard/greeting_test.dart` | The three time-of-day boundaries |
| `test/dashboard/dashboard_screen_test.dart` | Every section, the empty state, and overflow at two phone sizes |
| `test/dashboard/navigation_test.dart` | The five tabs, state preservation, settings, section links |
| `test/transactions/mock_transaction_repository_test.dart` | Totals, grouping, search, filters, CRUD, seed integrity |
| `test/transactions/transactions_screen_test.dart` | List, grouping, search, chips, the filter sheet, both empty states |
| `test/transactions/transaction_crud_test.dart` | Add, edit, delete with confirmation, and every validation rule |
| `test/transactions/architecture_test.dart` | **Rule 1, enforced:** no arithmetic on amounts outside the places allowed it |
| `test/reports/report_period_test.dart` | Window maths, stepping, future bounds, custom-range validation |
| `test/reports/mock_report_repository_test.dart` | Totals, ranking, bucketing, metrics, comparison, determinism |
| `test/reports/reports_screen_test.dart` | Period selection and stepping, empty periods, drill-down, entry points |
| `test/reports/annual_and_comparison_test.dart` | Annual report, month drill-down, comparison and its warnings |

The widget tests boot the real `LifePilotApp` and override only the repositories
(`test/*/harness.dart`). That is deliberate: the router's redirect guard is where much of
this behaviour lives, and a test that pumped a screen directly would pass even if routing
were broken.

The dashboard tests run at phone sizes (393x851 and 320x568) rather than the 800x600
default, because the default surface is wider and shorter than any Android device and hides
exactly the overflow worth checking for. Two real overflows and one infinite-constraint
crash were caught that way while building Phase 04.

`mock_dashboard_repository_test.dart` does the arithmetic the app itself is forbidden from
doing — net, remaining, ratios — so the mock's consistency is pinned once rather than
recomputed on every frame by a widget.

Goldens are font-hinting sensitive, so they are tagged `golden` and intended for local
review rather than as a cross-platform CI gate.

---

## Known limitations

- **Dark theme is a foundation, not a shipped mode.** It is complete enough to run and
  review, and is captured in goldens so it cannot rot, but the light theme is the launch design.
- **The font is the platform default** (Roboto on Android). To adopt a brand face, bundle it
  and set `AppTypography.fontFamily` — one line, and every style inherits it.
- **No localisation yet.** Strings are inline English. Swahili labels are typically longer
  than English, which is why status labels and card rows are built to shrink.
- **Charts are static.** No tooltips, selection or animation — Phase 02 is visual foundations.
- **Sign-in is a mock.** `MockAuthRepository` returns a fixed user after a delay. No Google
  SDK, no network call, no credential, nothing persisted. Phase 12 replaces that one class.
- **Nothing survives a restart.** Onboarding answers live in memory only; there is no
  storage layer yet, so relaunching the app returns to the welcome screen.
- **Language is recorded, not applied.** Choosing Kiswahili stores the preference; the
  interface stays English until localisation lands. The screen says so rather than
  implying otherwise.
- **Every dashboard figure is mock.** `MockDashboardRepository` stands where the Python
  reporting API will stand. Its derived values — net, remaining, each ratio — are written
  out as literals rather than computed, because that layer is what computes them, and
  putting the arithmetic in Dart would be the start of the duplicate finance engine the
  architecture exists to prevent.
- **Four of the five tabs are placeholders.** Activity, Budgets, Goals and Assistant say
  which phase they arrive in and show no figures, so a placeholder is never mistaken for a
  finished screen in a screenshot.
- **Quick actions save nothing.** Add expense, add income and record-by-voice open screens
  that say so. No microphone is touched.
- **The greeting does not re-render as time passes.** It is computed per build from an
  injectable clock, so an app left open from 11:59 to 12:01 keeps saying "Good morning"
  until something else rebuilds it. A timer for this is not worth the wakeups.
- **Transactions live in memory.** `MockTransactionRepository` holds the list for the life
  of the process. Adding, editing and deleting work and are visible immediately; relaunching
  the app restores the seed. Phase 13 replaces that one class.
- **The dashboard and the transaction list do not share data.** The dashboard's figures come
  from its own mock of the reporting API, so a transaction added in Activity does not change
  the dashboard's totals or its recent-activity list. Deriving the dashboard from recorded
  transactions is real financial reporting, which Phase 05 is explicitly not allowed to
  build — so the two stay separate until a backend joins them.
- **Everything is derived from one source.** The dashboard reads the report repository,
  reports read the transaction repository, and the transaction repository holds the records.
  A figure cannot differ between two screens, and a test asserts the dashboard and the
  reports screen agree for the same month.
- **The budget limit and the savings goals are still authored.** Neither feature exists yet,
  so there is nothing to read them from. The budget's *spending* is real — it is the period's
  expenses — so the budget card and the Money out card above it cannot disagree. A monthly
  budget is only shown for a month; against a year it would be comparing a year's spending
  with a month's limit.
- **Three years of history, generated.** `TransactionHistory` produces about 340 records from
  a fixed seed, so the same clock always yields the same figures: a report opened twice reads
  the same both times. The current month is hand-written; everything older is generated.
