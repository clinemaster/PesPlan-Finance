import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/budgets/domain/budget_status.dart';

void main() {
  group('thresholds', () {
    const thresholds = BudgetThresholds.standard;

    test('nothing spent is on track', () {
      expect(thresholds.levelFor(0), BudgetStatus.onTrack);
    });

    test('below three quarters is on track', () {
      expect(thresholds.levelFor(0.74), BudgetStatus.onTrack);
    });

    test('three quarters begins approaching', () {
      // The boundary is inclusive: at exactly 75% the user has reached
      // the level, not almost reached it.
      expect(thresholds.levelFor(0.75), BudgetStatus.approaching);
      expect(thresholds.levelFor(0.89), BudgetStatus.approaching);
    });

    test('ninety percent begins near limit', () {
      expect(thresholds.levelFor(0.90), BudgetStatus.nearLimit);
      expect(thresholds.levelFor(0.99), BudgetStatus.nearLimit);
    });

    test('spending the whole budget is already over', () {
      // Spending exactly the limit leaves nothing for the rest of the
      // month, which is the fact worth reporting — "on track" with zero
      // left would be true and useless.
      expect(thresholds.levelFor(1.0), BudgetStatus.over);
      expect(thresholds.levelFor(2.5), BudgetStatus.over);
    });

    test('every level is reachable and they are in order', () {
      final seen = [
        for (final ratio in [0.0, 0.8, 0.95, 1.2]) thresholds.levelFor(ratio),
      ];

      expect(seen, BudgetStatus.values);
    });

    test('custom thresholds move the boundaries', () {
      // The point of injecting them: a change is one decision in one
      // place, not an edit in every widget that colours a bar.
      const earlier = BudgetThresholds(approaching: 0.5, nearLimit: 0.7);

      expect(earlier.levelFor(0.55), BudgetStatus.approaching);
      expect(earlier.levelFor(0.75), BudgetStatus.nearLimit);
      expect(BudgetThresholds.standard.levelFor(0.55), BudgetStatus.onTrack);
    });

    test('two sets with the same boundaries are equal', () {
      expect(const BudgetThresholds(), BudgetThresholds.standard);
    });
  });

  group('what each level says', () {
    test('every level has a label and an explanation', () {
      for (final status in BudgetStatus.values) {
        expect(status.label, isNotEmpty);
        expect(status.explanation, isNotEmpty);
      }
    });

    test('labels are calm, not scolding', () {
      // A budget is a plan the user made. An app that shouts at them for
      // missing it is one they stop opening.
      for (final status in BudgetStatus.values) {
        expect(status.label, isNot(contains('!')));
        expect(status.label.toLowerCase(), isNot(contains('you')));
      }
    });

    test('labels are unique, so a chip never reads ambiguously', () {
      final labels = BudgetStatus.values.map((s) => s.label).toSet();
      expect(labels, hasLength(BudgetStatus.values.length));
    });

    test('only the levels worth acting on ask for attention', () {
      // Badging all four makes every row wallpaper and the one that
      // matters invisible.
      expect(BudgetStatus.onTrack.needsAttention, isFalse);
      expect(BudgetStatus.approaching.needsAttention, isFalse);
      expect(BudgetStatus.nearLimit.needsAttention, isTrue);
      expect(BudgetStatus.over.needsAttention, isTrue);
    });
  });
}
