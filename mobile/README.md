# LifePilot Finance — Design System (Phase 02)

The visual language and reusable component set for the LifePilot Finance mobile app.
**Phase 02 delivers the design system only** — no authentication, no transactions, no
dashboard, no backend. Every figure on screen is placeholder data.

---

## Running the showcase

```bash
cd mobile
flutter pub get
flutter run            # launches the design system showcase
```

The app's entry point is currently the showcase, because there are no product screens yet.
Phase 03 replaces `main.dart` with the real root widget; the showcase then stays available
for internal review but leaves the production navigation tree.

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
├── main.dart                        launches the showcase (Phase 02 only)
├── core/
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
└── showcase/                        internal review screen
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
