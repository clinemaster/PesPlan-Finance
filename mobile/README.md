# LifePilot Finance — Mobile App

The Flutter client for LifePilot Finance. Built in phases:

| Phase | Delivers | State |
|---|---|---|
| 02 | Design system — tokens, theme, components | done |
| 03 | Welcome, mock Google sign-in, onboarding | done |
| 04 | Navigation shell and dashboard | done |
| 05 | Transactions — list, search, filter, add, edit, delete | done |
| 06 | Reports — periods, breakdown, annual, year comparison | done |
| 07 | Budgets — overview, overall and category limits, create, edit, delete | done |
| 08 | Savings goals — progress, contributions, withdrawals, history | done |
| 09 | Voice entry — speak a transaction, review it, confirm it | done |
| 10 | Assistant — ask about your money, answered from your own figures | done |
| 11 | Profile, settings and the subscription presentation | done |
| 12 | Google Sign-In — the real provider, with the credential in the keystore | done |

**Sign-in is now real, once a build has been given Google credentials.** A build without
them falls back to the stand-in and says so on the welcome screen — see
[Google Sign-In setup](../docs/GOOGLE_SIGN_IN_SETUP.md). **There is still no backend and no
real financial data**: every figure in the app is mock, and nothing reads the credential yet.

---

## Running the app

```bash
cd mobile
flutter pub get
flutter run            # starts at the welcome screen, with the stand-in sign-in

# with real Google Sign-In, once the project has OAuth clients:
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<the web client id>
```

Without that define there is no Google project behind the build, so sign-in uses the local
stand-in — which is what every clone gets, and what keeps the app reviewable without
provisioning credentials first. The welcome screen says which one you have.
[docs/GOOGLE_SIGN_IN_SETUP.md](../docs/GOOGLE_SIGN_IN_SETUP.md) is the whole path from
nothing to a working sign-in, including what each failure message means.

`main.dart` launches the real root widget and its router. After onboarding the app settles
into a five-tab shell — Home, Activity, Budgets, Goals, Assistant. All five are built; there
are no placeholder screens left.

The Phase 02 design system showcase is still available at `/showcase`, reachable from
Profile & settings, so the visual language stays reviewable without being what the app
opens on.

### Seeing the states that are hard to reach

Both controls are review affordances and go away with the mock data.

- **Sign-in cancelled / failed** — long-press the brand mark on the welcome screen and pick
  what the next attempt returns. Only on a stand-in build: a real provider will not fail to
  order, so the menu is not there. `--dart-define=SIGN_IN_PROVIDER=mock` forces the
  stand-in on a machine that does have credentials.
- **The empty dashboard** — Profile & settings → Review controls → *Show the empty
  dashboard*.
- **The assistant failing** — Profile & settings → Review controls → *Make the assistant
  fail*. The next question comes back as an error with a retry beside it.
- **The voice states** — press the microphone repeatedly. The mock cycles: a clear expense,
  a clear income, an extraction missing its amount, then a failure. A build where only the
  happy path can be reached is a build whose error state nobody has looked at.

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
├── main.dart                        ProviderScope, both stores, launch refresh
├── app.dart                         MaterialApp.router, theme mode
├── core/
│   ├── router/
│   │   ├── routes.dart              every route path, as constants
│   │   └── app_router.dart          go_router + the session guard
│   ├── config/
│   │   └── auth_config.dart         which provider this build signs in with
│   ├── storage/
│   │   ├── key_value_store.dart     persisted state; in-memory by default
│   │   └── credential_store.dart    the keystore; a different door, on purpose
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
│   │   │                            SessionRestore, Country, AppLanguage,
│   │   │                            UserProfile, ProfileValidator — pure Dart
│   │   ├── data/
│   │   │   ├── google_auth_repository.dart  the real one: SDK outcomes to
│   │   │   │                                screen states, token to the keystore
│   │   │   ├── google_sign_in_client.dart   the seam over the plugin singleton
│   │   │   ├── credential_vault.dart        the ID token, and nothing else
│   │   │   ├── mock_auth_repository.dart    the stand-in, for builds with no
│   │   │   │                                Google project behind them
│   │   │   └── session_store.dart           session and profile in preferences
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
│   ├── budgets/
│   │   ├── domain/                  Budget, BudgetKind, BudgetStatus and its
│   │   │                            thresholds, BudgetProgress, BudgetBoard,
│   │   │                            BudgetValidator — pure Dart
│   │   ├── data/
│   │   │   ├── budget_store.dart    the month's plans as JSON
│   │   │   └── mock_budget_repository.dart   measures plans against the
│   │   │                            report repository's spending
│   │   └── presentation/
│   │       ├── providers/           repository, thresholds, selected month,
│   │       │                        board, write actions
│   │       ├── widgets/             overall card, category row, status chip,
│   │       │                        month stepper, detail sheet
│   │       └── screens/             budgets, add/edit form, edit loader
│   ├── savings/
│   │   ├── domain/                  SavingsGoal, GoalIcon, GoalMovement,
│   │   │                            GoalProgress, SavingsBoard, GoalTiming,
│   │   │                            SavingsValidator — pure Dart
│   │   ├── data/
│   │   │   ├── savings_store.dart   goals and movements as JSON
│   │   │   └── mock_savings_repository.dart   derives every balance from
│   │   │                            the goal's own movements
│   │   └── presentation/
│   │       ├── providers/           repository, board, one goal, its
│   │       │                        movements, write actions
│   │       ├── widgets/             total card, goal card, movement row,
│   │       │                        icon picker
│   │       └── screens/             goals, goal detail, add/edit form,
│   │                                edit loader, contribute/withdraw
│   ├── voice/
│   │   ├── domain/                  VoiceLanguage, VoiceTranscript,
│   │   │                            VoiceExtraction, VoiceField,
│   │   │                            VoiceSession and its stages
│   │   ├── data/
│   │   │   ├── transcript_reader.dart   reads amounts, categories, dates
│   │   │   │                        and direction out of a sentence
│   │   │   └── mock_voice_repository.dart   stands in for a speech
│   │   │                            service; opens no microphone
│   │   └── presentation/
│   │       ├── providers/           the session, start to finish
│   │       ├── widgets/             mic button, language picker,
│   │       │                        examples, transcript, extracted rows
│   │       └── screens/voice_entry_screen.dart
│   ├── assistant/
│   │   ├── domain/                  ChatMessage, Conversation,
│   │   │                            AssistantInsight, AssistantUsage,
│   │   │                            SuggestionGroup
│   │   ├── data/
│   │   │   ├── financial_snapshot.dart   what the assistant may see,
│   │   │   │                        gathered from the other repositories
│   │   │   ├── mock_assistant_repository.dart   reads the question,
│   │   │   │                        answers from those figures
│   │   │   └── conversation_store.dart   the words, not the cards
│   │   └── presentation/
│   │       ├── providers/           conversations, usage, failure switch
│   │       ├── widgets/             bubble, insight card, typing, chips
│   │       └── screens/             assistant, conversation history
│   ├── shell/presentation/          the five-tab frame
│   └── settings/
│       ├── domain/                  NotificationChannel, AppTimezone,
│       │                            Plan, PlanFeature, Subscription
│       ├── data/settings_store.dart what the user chose, kept
│       └── presentation/
│           ├── providers/           notifications, timezone, plan
│           ├── widgets/             rows, sections, plan card,
│           │                        comparison, placeholder note
│           ├── settings_screen.dart the hub
│           └── screens/             profile, preferences, notifications,
│                                    security & privacy, subscription,
│                                    help
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
flutter test                         # 1011 tests
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
| `test/auth/auth_config_test.dart` | Which provider a build resolves to, and what reaches the plugin |
| `test/auth/credential_store_test.dart` | The secure store's contract and the vault over it |
| `test/auth/google_auth_repository_test.dart` | Every SDK outcome mapped to a screen state, the token written and cleared, and sign-out surviving both halves failing |
| `test/auth/provider_wiring_test.dart` | That configuration chooses the repository, and the launch refresh |
| `test/auth/boundary_test.dart` | That the SDK and the keystore stay behind their own files, and the manifest keeps its permission and backup rules |

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
| `test/budgets/budget_status_test.dart` | Every threshold boundary, the labels, and which levels ask for attention |
| `test/budgets/budget_validator_test.dart` | Amount, category, note and the duplicate rule, including editing |
| `test/budgets/mock_budget_repository_test.dart` | Remaining, overspend, ratios, ordering, unbudgeted spending, CRUD, seed integrity |
| `test/budgets/budgets_screen_test.dart` | Month stepping, the overall card, the category list, all four statuses, the detail sheet, both empty states, two phone sizes |
| `test/budgets/budget_crud_test.dart` | Create, edit, delete with confirmation, every validation rule, and the dashboard's budget card |
| `test/savings/savings_validator_test.dart` | Name, target, opening amount, dates, contribution and withdrawal rules, and the time-remaining labels |
| `test/savings/mock_savings_repository_test.dart` | Balances derived from movements, completion, ordering, totals, CRUD, the withdrawal backstop, seed integrity |
| `test/savings/goals_screen_test.dart` | The total, goal cards, ordering, the completed section, the empty state, dashboard entry points, two phone sizes |
| `test/savings/goal_crud_test.dart` | Create, edit, delete with confirmation, every validation rule, and the completion warning |
| `test/savings/goal_movements_test.dart` | Contributions, withdrawals, withdrawal limits, history, and that neither touches transactions |
| `test/voice/transcript_reader_test.dart` | Kiswahili and English number words, verbs, category words, dates, and what is left unknown |
| `test/voice/voice_flow_test.dart` | Every stage from the microphone to the saved transaction, both entry points, uncertainty, and the manual fallback |
| `test/assistant/mock_assistant_repository_test.dart` | That every answer quotes the same figures the other screens show, what it refuses to guess, the allowance, and the insight cards |
| `test/assistant/assistant_screen_test.dart` | The welcome, suggestions, asking, the typing state, failure and retry, conversation history, delete, and a relaunch |
| `test/settings/settings_test.dart` | The hub, profile editing and its validation, every preference, notification switches and their persistence, the security and privacy placeholders, the plan comparison and mock upgrade, help, and sign-out |
| `test/persistence/persistence_test.dart` | Session, profile, transactions and preferences across a relaunch; unreadable stored state |
| `test/persistence/relaunch_test.dart` | The whole app restarted over the same storage |

The widget tests boot the real `LifePilotApp` and override only the repositories
(`test/*/harness.dart`). That is deliberate: the router's redirect guard is where much of
this behaviour lives, and a test that pumped a screen directly would pass even if routing
were broken.

The screen tests run at phone sizes (393x851 and 320x568) rather than the 800x600 default,
because the default surface is wider and shorter than any Android device and hides exactly
the overflow worth checking for. Every overflow this project has found was invisible at the
default size — including two in Phase 07: the budget detail sheet ran 90px past the bottom
of its own sheet, and the empty-month invitation pushed its own button off a 320px screen.

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
- **Sign-in is real, and a build without credentials says it is not.** `GoogleAuthRepository`
  drives the `google_sign_in` plugin, keeps the ID token in the Android keystore and refreshes
  it at every launch. A build with no `GOOGLE_SERVER_CLIENT_ID` uses `MockAuthRepository`
  instead — it invents a user, contacts nothing and holds no credential — and the welcome
  screen, the profile email badge and the security screen each say so rather than implying a
  Google account that does not exist.
- **Nothing verifies the token, because nothing should here.** An ID token is a signed claim,
  and the thing that checks the signature is the backend that will accept it; an app
  verifying its own credential proves nothing. The app obtains it and keeps it safe. Nothing
  reads it until there is a server to send it to.
- **A failed credential refresh never signs anyone out.** The provider cannot tell a revoked
  account from a phone in a tunnel, so the session restored from storage always stands. The
  refresh is only ever an improvement.
- **Language is recorded, not applied.** Choosing Kiswahili stores the preference; the
  interface stays English until localisation lands. The screen says so rather than
  implying otherwise.
- **Every dashboard figure is mock.** `MockDashboardRepository` stands where the Python
  reporting API will stand. Its derived values — net, remaining, each ratio — are written
  out as literals rather than computed, because that layer is what computes them, and
  putting the arithmetic in Dart would be the start of the duplicate finance engine the
  architecture exists to prevent.
- **The subscription is a presentation, not a product.** No price, no store, no receipt, no
  entitlement check: "Try Premium" sets a flag on the device so the Premium screens can be
  reviewed, and says so before and after. Nothing in the app reads the plan to decide what a
  user may do, and the feature table is a proposal to argue with rather than a commitment.
- **Several settings are deliberately inert, and say so.** App lock and biometrics are
  switched off and cannot be turned on; export, account deletion, the help centre, support,
  feedback and the legal documents each open a sheet explaining what they will do and that
  they do not do it yet. Confirming account deletion deletes nothing — faking it would leave
  someone's data here while telling them it had gone.
- **Choosing Kiswahili saves the choice and changes nothing else.** The interface is English
  until localisation lands, and the preference screen says that rather than letting the user
  discover it.
- **The assistant is a keyword matcher, not a model.** No AI provider, no API key, no
  network call, nothing sent anywhere. It reads the question for what it is about, fetches
  the matching numbers from the repositories that own them, and writes a sentence around
  them — so every figure it states is one the user can go and check on Reports, Budgets or
  Goals. Phase 18 replaces that one class.
- **It says what it cannot do.** No investment or tax advice, no projected dates, and no
  answer at all where there is no data: "you have not set an overall budget" rather than a
  budget answer of zero. The daily allowance on screen is a mock — nothing is billed,
  enforced or expired.
- **An empty state's action can say what it does.** `EmptyState` always put a plus on its
  button, which reads wrong on "Try again"; it now takes an `actionIcon`, defaulting to the
  plus that suits the common case.
- **Voice opens no microphone.** There is no audio, no permission request, no speech
  recognition and no model. The screen runs the real flow — listening, understanding,
  transcript, review — against a mock that answers from a list, and the timer is the only
  thing actually running. What is *not* pretend is the reader: the transcript the user
  corrects is really parsed, so changing "elfu kumi" to "elfu ishirini" really does change
  the amount. Phase 17 replaces the mock service; the reader goes with it.
- **Nothing spoken is saved without a confirmation.** The extraction is presented as a
  suggestion, every field can be changed, and an amount that was not heard is asked for
  rather than guessed — a voice feature that files money on its own is one people stop
  trusting the first time it mishears.
- **Quick actions save nothing.** Add expense, add income and record-by-voice open screens
  that say so. No microphone is touched.
- **The greeting does not re-render as time passes.** It is computed per build from an
  injectable clock, so an app left open from 11:59 to 12:01 keeps saying "Good morning"
  until something else rebuilds it. A timer for this is not worth the wakeups.
- **Everything is derived from one source.** Budgets read the report repository, the
  dashboard reads reports, budgets and savings, reports read the transaction repository, and
  the transaction repository holds the records. A figure cannot differ between two screens,
  and tests assert that the dashboard agrees with reports for the same month and that a
  budget agrees with both.
- **Nothing on the dashboard is authored any more.** Each card reads the feature that owns
  it, savings included, so the preview and the Goals screen cannot quote different totals. A
  monthly budget is only shown for a month; against a year it would compare a year's
  spending with a month's limit.
- **Saving is not spending.** A contribution is recorded against its goal and nowhere else:
  it never reaches the transaction repository, so it cannot appear as an expense, move the
  month's net, or be counted twice by the reports. That is a product decision as much as a
  technical one — money set aside has not left the user's hands — and two tests pin it.
- **A goal's balance is its history, added up.** Nothing stores "saved so far"; it is
  derived from the goal's movements every time, so the figure on the card and the list
  behind it cannot drift apart. Withdrawals are capped at what the goal holds, in the form
  and again in the repository, because a goal cannot hold less than nothing.
- **Savings goals are deliberately plain.** No interest, no projections, no "you will reach
  this by March at your current rate", no reminders. A target, what is in it, and what is
  left — the forecasting is a later phase's decision, and inventing a rate from four
  contributions would be a prediction the app cannot stand behind.
- **Budgets are monthly, and nothing else.** No weekly limits, no rollover of what went
  unspent, no copying last month's plans forward, and no alerts — a budget is a limit for
  one named month, measured when the screen is opened. The thresholds that decide "near
  limit" are one injectable value (`BudgetThresholds`), so moving them is one decision
  rather than an edit in every widget that colours a bar.
- **The seeded goals are review data too.** Four goals with their movement history, one of
  them finished and one with a withdrawal in it, so the completed section and both
  directions of movement are visible without anyone having to create data first. Same rule
  as the budgets: written once, the user's from then on.
- **The seeded budgets are review data.** Six plans for the current month, sized against
  what the generated history actually spends so the screen opens on a real mix — most
  categories fine, one close, one over — rather than everything comfortably green. They are
  written once on first launch and are the user's from then on: editing or deleting them
  persists, and deleting the last one leaves an empty screen rather than handing the seed
  back.
- **Three years of history, generated.** `TransactionHistory` produces about 340 records from
  a fixed seed, so the same clock always yields the same figures: a report opened twice reads
  the same both times. The current month is hand-written; everything older is generated.

---

## Persistence

State survives a relaunch, in `shared_preferences` behind `KeyValueStore`:

| What | Where | Notes |
|---|---|---|
| Session and profile | `session.*` | Written when setup completes, and on later edits |
| Transactions | `transactions.all` | The whole list as JSON, rewritten on every change |
| Budgets | `budgets.all` | Same arrangement; written even when empty, so deleting the last budget is not undone by the seed |
| Savings goals | `savings.goals` | Plans only — no balance is stored |
| Goal movements | `savings.movements` | Every contribution and withdrawal; the balances are derived from these |
| Conversations | `assistant.conversations` | The words only — insight cards are rebuilt from today's figures, never restored stale |
| Notification choices | `settings.notifications` | Which channels are on |
| Timezone | `settings.timezone` | An IANA id, ready for a server that schedules |
| Mock plan | `settings.plan` | Review state only — never an entitlement |
| Theme | `settings.themeMode` | |

And one thing that is deliberately not in there, in `flutter_secure_storage` behind
`CredentialStore`:

| What | Where | Notes |
|---|---|---|
| Google ID token | `auth.google.idToken` | The Android keystore, not the preferences file. Refreshed at launch, deleted on sign-out, and excluded from Android backup and device transfer |

Three things are worth knowing.

**Controllers restore themselves synchronously inside `build()`.** `main()` opens storage
before the first frame and hands it to the provider scope ready to read, so a returning user
goes straight to their dashboard. An async bootstrap would paint the welcome screen for a
frame first, and that flash is more expensive than the few milliseconds of reading one file.

**Unreadable stored state is treated as absent, never fatal.** A damaged session reads as no
session, and a damaged transaction or budget list reads as empty. Signing in again is
recoverable, and losing a plan is recoverable; a crash loop on launch is not.

**No credential is stored here.** `shared_preferences` is an unencrypted file. What is kept
is a name, an email and the answers from setup — all of it already on screen whenever the app
is open. The ID token goes to `flutter_secure_storage` instead, through a different interface
entirely: `KeyValueStore` has no "secure" flag, and `CredentialStore` is not something a
screen is handed, so nothing in the app can write a credential to preferences by mistake.

A JSON blob rather than `drift`: there is no server yet, so there is nothing to cache and
nothing to query server-side. A few hundred records is about a hundred kilobytes, and
rewriting it on every change is wasteful in principle and imperceptible in practice at this
size. When the list outgrows one write, the move happens inside `TransactionStore` without
touching a screen.
