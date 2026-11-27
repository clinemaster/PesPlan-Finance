import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/money/money.dart';
import 'package:lifepilot_finance/features/savings/data/mock_savings_repository.dart';
import 'package:lifepilot_finance/features/savings/domain/goal_movement.dart';
import 'package:lifepilot_finance/features/savings/domain/savings_goal.dart';

import 'harness.dart';

final DateTime today = SavingsHarness.now;

MockSavingsRepository savingsWith({
  List<SavingsGoal>? goals,
  List<GoalMovement>? movements,
}) => MockSavingsRepository(
  now: () => today,
  seedGoals: goals,
  seedMovements: movements,
  delay: Duration.zero,
);

void main() {
  group('a balance is its history, added up', () {
    test('contributions add up', () async {
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 120000),
          paidIn(id: 'b', amount: 80000),
        ],
      ).board();

      final progress = board.active.single;
      expect(progress.saved.minorUnits, 200000);
      expect(progress.contributed.minorUnits, 200000);
      expect(progress.movementCount, 2);
    });

    test('withdrawals come back off', () async {
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 200000),
          tookOut(id: 'b', amount: 50000),
        ],
      ).board();

      final progress = board.active.single;
      expect(progress.saved.minorUnits, 150000);
      expect(progress.contributed.minorUnits, 200000);
      expect(progress.withdrawn.minorUnits, 50000);
    });

    test('a goal with no movements holds nothing, not null', () async {
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: const [],
      ).board();

      final progress = board.active.single;
      expect(progress.saved.minorUnits, 0);
      expect(progress.ratio, 0);
      expect(progress.hasMovements, isFalse);
    });

    test('one goal cannot be credited with another goal\'s money', () async {
      final board = await savingsWith(
        goals: [
          goal(target: 500000, id: 'a', name: 'A'),
          goal(target: 500000, id: 'b', name: 'B'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'a', amount: 100000),
          paidIn(id: 'm2', goalId: 'b', amount: 250000),
        ],
      ).board();

      final byId = {for (final p in board.active) p.goal.id: p};
      expect(byId['a']!.saved.minorUnits, 100000);
      expect(byId['b']!.saved.minorUnits, 250000);
    });
  });

  group('progress', () {
    test('remaining is the target less what is saved', () async {
      final board = await savingsWith(
        goals: [goal(target: 2000000)],
        movements: [paidIn(amount: 850000)],
      ).board();

      final progress = board.active.single;
      expect(progress.remaining.minorUnits, 1150000);
      expect(progress.ratio, closeTo(0.425, 0.0001));
      expect(progress.percent, 43);
    });

    test('remaining never goes negative', () async {
      // "You need −120,000 more" is not a sentence anyone should read.
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 620000)],
      ).board();

      final progress = board.completed.single;
      expect(progress.remaining.minorUnits, 0);
    });

    test(
      'over-saving is reported honestly, and the bar stops at full',
      () async {
        final board = await savingsWith(
          goals: [goal(target: 500000)],
          movements: [paidIn(amount: 750000)],
        ).board();

        final progress = board.completed.single;
        expect(progress.saved.minorUnits, 750000);
        expect(progress.percent, 150);
        expect(progress.cappedPercent, 100);
        expect(progress.barValue, 1);
      },
    );

    test('a zero target does not produce a NaN ratio', () async {
      // The validator refuses zero; this is for a goal stored by an
      // older build, where a NaN paints a bar of indeterminate length.
      final board = await savingsWith(
        goals: [goal(target: 0)],
        movements: [paidIn(amount: 10000)],
      ).board();

      final progress = board.active.single;
      expect(progress.ratio, 0);
      expect(progress.isComplete, isFalse);
    });

    test('taking everything back out leaves nothing, not less', () async {
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 100000),
          tookOut(id: 'b', amount: 100000),
        ],
      ).board();

      expect(board.active.single.saved.minorUnits, 0);
    });
  });

  group('completion', () {
    test('reaching the target completes the goal', () async {
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 500000)],
      ).board();

      expect(board.active, isEmpty);
      expect(board.completed.single.isComplete, isTrue);
      expect(board.completed.single.remaining.minorUnits, 0);
    });

    test('a goal one shilling short is not complete', () async {
      // Nothing is rounded into a completion the user did not reach.
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [paidIn(amount: 499999)],
      ).board();

      expect(board.completed, isEmpty);
      expect(board.active.single.isComplete, isFalse);
    });

    test('a withdrawal can un-complete a goal', () async {
      // The state follows the money. A goal that was finished and then
      // raided is a goal being saved toward again.
      final board = await savingsWith(
        goals: [goal(target: 500000)],
        movements: [
          paidIn(id: 'a', amount: 500000),
          tookOut(id: 'b', amount: 100000),
        ],
      ).board();

      expect(board.completed, isEmpty);
      expect(board.active.single.remaining.minorUnits, 100000);
    });
  });

  group('the board', () {
    test('puts the goal closest to done first', () async {
      final board = await savingsWith(
        goals: [
          goal(target: 1000000, id: 'early', name: 'Early'),
          goal(target: 200000, id: 'close', name: 'Close'),
          goal(target: 500000, id: 'middle', name: 'Middle'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'early', amount: 100000),
          paidIn(id: 'm2', goalId: 'close', amount: 180000),
          paidIn(id: 'm3', goalId: 'middle', amount: 250000),
        ],
      ).board();

      expect(board.active.map((p) => p.goal.id), ['close', 'middle', 'early']);
    });

    test('totals cover the active goals only', () async {
      // Rolling finished goals in makes the headline climb every time one
      // completes, which reads as progress on what is left.
      final board = await savingsWith(
        goals: [
          goal(target: 500000, id: 'open'),
          goal(target: 300000, id: 'done'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'open', amount: 200000),
          paidIn(id: 'm2', goalId: 'done', amount: 300000),
        ],
      ).board();

      expect(board.totalSaved.minorUnits, 200000);
      expect(board.totalTarget.minorUnits, 500000);
      expect(board.ratio, closeTo(0.4, 0.0001));
      expect(board.completedCount, 1);
    });

    test('is empty when there are no goals at all', () async {
      final board = await savingsWith(goals: const []).board();

      expect(board.isEmpty, isTrue);
      expect(board.totalSaved.minorUnits, 0);
      expect(board.ratio, 0);
    });

    test('is not empty when every goal is finished', () async {
      final board = await savingsWith(
        goals: [goal(target: 100000)],
        movements: [paidIn(amount: 100000)],
      ).board();

      expect(board.isEmpty, isFalse);
      expect(board.active, isEmpty);
      expect(board.hasCompleted, isTrue);
    });
  });

  group('history', () {
    test('comes back newest first', () async {
      final movements = await savingsWith(
        goals: [goal(target: 900000)],
        movements: [
          paidIn(id: 'old', amount: 10000, day: 2),
          paidIn(id: 'new', amount: 10000, day: 20),
          paidIn(id: 'middle', amount: 10000, day: 11),
        ],
      ).movements('goal');

      expect(movements.map((m) => m.id), ['new', 'middle', 'old']);
    });

    test('belongs to one goal only', () async {
      final movements = await savingsWith(
        goals: [
          goal(target: 100000, id: 'a'),
          goal(target: 100000, id: 'b'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'a', amount: 1000),
          paidIn(id: 'm2', goalId: 'b', amount: 1000),
        ],
      ).movements('a');

      expect(movements.map((m) => m.id), ['m1']);
    });

    test('a movement with no note is titled by its kind', () async {
      final movements = await savingsWith(
        goals: [goal(target: 100000)],
        movements: [
          paidIn(id: 'bare', amount: 1000),
          tookOut(id: 'noted', amount: 500, description: 'Taxi home'),
        ],
      ).movements('goal');

      expect(movements.firstWhere((m) => m.id == 'bare').title, 'Contribution');
      expect(movements.firstWhere((m) => m.id == 'noted').title, 'Taxi home');
    });
  });

  group('writing', () {
    test('create adds a goal with no history', () async {
      final repository = savingsWith(goals: const []);

      await repository.create(goal(target: 400000, id: 'new'));
      final board = await repository.board();

      expect(repository.allGoals, hasLength(1));
      expect(board.active.single.saved.minorUnits, 0);
      expect(board.active.single.hasMovements, isFalse);
    });

    test('an opening amount is recorded as a contribution', () async {
      // Stored as history rather than on the goal, so a goal that starts
      // at 200,000 has the same shape as one that got there by saving.
      final repository = savingsWith(goals: const []);

      await repository.create(
        goal(target: 400000, id: 'new'),
        initialMinorUnits: 200000,
      );
      final board = await repository.board();
      final movements = await repository.movements('new');

      expect(board.active.single.saved.minorUnits, 200000);
      expect(movements, hasLength(1));
      expect(movements.single.isContribution, isTrue);
    });

    test('update replaces in place and keeps the history', () async {
      final repository = savingsWith(
        goals: [goal(target: 500000, id: 'g')],
        movements: [paidIn(goalId: 'g', amount: 200000)],
      );

      await repository.update(
        goal(target: 700000, id: 'g', name: 'Bigger plan'),
      );
      final board = await repository.board();

      expect(repository.allGoals.single.name, 'Bigger plan');
      expect(board.active.single.saved.minorUnits, 200000);
      expect(board.active.single.remaining.minorUnits, 500000);
    });

    test('lowering the target below what is saved completes the goal, '
        'without touching the movements', () async {
      final repository = savingsWith(
        goals: [goal(target: 900000, id: 'g')],
        movements: [
          paidIn(id: 'a', goalId: 'g', amount: 300000),
          paidIn(id: 'b', goalId: 'g', amount: 200000),
        ],
      );

      await repository.update(goal(target: 400000, id: 'g'));
      final board = await repository.board();
      final movements = await repository.movements('g');

      expect(board.completed.single.isComplete, isTrue);
      expect(board.completed.single.saved.minorUnits, 500000);
      expect(movements, hasLength(2), reason: 'history must survive');
    });

    test('update refuses a goal it does not hold', () async {
      final repository = savingsWith(goals: const []);

      expect(
        () => repository.update(goal(target: 1000, id: 'ghost')),
        throwsStateError,
      );
    });

    test('delete removes the goal and its movements', () async {
      final repository = savingsWith(
        goals: [goal(target: 100000, id: 'g')],
        movements: [paidIn(goalId: 'g', amount: 1000)],
      );

      await repository.delete('g');

      expect(repository.allGoals, isEmpty);
      expect(repository.allMovements, isEmpty);
      expect((await repository.board()).isEmpty, isTrue);
    });

    test('delete leaves other goals and their history alone', () async {
      final repository = savingsWith(
        goals: [
          goal(target: 100000, id: 'a'),
          goal(target: 100000, id: 'b'),
        ],
        movements: [
          paidIn(id: 'm1', goalId: 'a', amount: 1000),
          paidIn(id: 'm2', goalId: 'b', amount: 2000),
        ],
      );

      await repository.delete('a');

      expect(repository.allGoals.map((g) => g.id), ['b']);
      expect(repository.allMovements.map((m) => m.id), ['m2']);
    });

    test('a contribution moves the balance', () async {
      final repository = savingsWith(
        goals: [goal(target: 500000, id: 'g')],
        movements: const [],
      );

      await repository.addMovement(paidIn(goalId: 'g', amount: 75000));

      expect((await repository.board()).active.single.saved.minorUnits, 75000);
    });

    test('a withdrawal larger than the balance is refused', () async {
      // The backstop for the rule the form enforces: a goal cannot hold
      // less than nothing, and the server side must not accept a state
      // the client forgot to check.
      final repository = savingsWith(
        goals: [goal(target: 500000, id: 'g')],
        movements: [paidIn(goalId: 'g', amount: 50000)],
      );

      expect(
        () => repository.addMovement(tookOut(goalId: 'g', amount: 60000)),
        throwsStateError,
      );
      expect((await repository.board()).active.single.saved.minorUnits, 50000);
    });

    test('a withdrawal of exactly the balance is allowed', () async {
      final repository = savingsWith(
        goals: [goal(target: 500000, id: 'g')],
        movements: [paidIn(goalId: 'g', amount: 50000)],
      );

      await repository.addMovement(tookOut(goalId: 'g', amount: 50000));

      expect((await repository.board()).active.single.saved.minorUnits, 0);
    });

    test('a movement for a goal that is gone is refused', () async {
      final repository = savingsWith(goals: const []);

      expect(
        () => repository.addMovement(paidIn(goalId: 'ghost', amount: 1000)),
        throwsStateError,
      );
    });

    test('new ids are unique', () async {
      final repository = savingsWith(goals: const []);

      expect({for (var i = 0; i < 50; i++) repository.newId()}, hasLength(50));
    });
  });

  group('savings are not transactions', () {
    test('the repository has no transaction dependency at all', () {
      // The rule this phase turns on: setting money aside is not
      // spending it. If this class ever needs a TransactionRepository to
      // be constructed, a contribution has become an expense and every
      // report in the app is overstating what the user spent.
      final repository = MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      );

      expect(repository.allGoals, isNotEmpty);
    });
  });

  group('the seed', () {
    test('opens on a real mix, including one finished goal', () async {
      final board = await MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      ).board();

      expect(board.active, isNotEmpty);
      expect(board.completed, hasLength(1));
      expect(board.activeCount, 3);
    });

    test('its figures are its own movements', () async {
      final repository = MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      );
      final board = await repository.board();

      for (final progress in [...board.active, ...board.completed]) {
        final movements = await repository.movements(progress.goal.id);

        var expected = 0;
        for (final movement in movements) {
          expected += movement.isContribution
              ? movement.amount.minorUnits
              : -movement.amount.minorUnits;
        }

        expect(
          progress.saved.minorUnits,
          expected,
          reason: '${progress.goal.name} does not match its own history',
        );
      }
    });

    test('includes a withdrawal, so that path is visible on review', () async {
      final repository = MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      );

      expect(repository.allMovements.any((m) => !m.isContribution), isTrue);
    });

    test('amounts are positive magnitudes, whichever way they went', () async {
      final repository = MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      );

      for (final movement in repository.allMovements) {
        expect(movement.amount.minorUnits, greaterThan(0));
      }
    });

    test('every goal carries an icon the design system can resolve', () {
      final repository = MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      );

      final keys = {for (final icon in GoalIcon.all) icon.key};
      for (final goal in repository.allGoals) {
        expect(keys, contains(goal.iconKey), reason: goal.name);
      }
    });
  });

  group('money', () {
    test('every figure is in minor units of the same currency', () async {
      final board = await MockSavingsRepository(
        now: () => today,
        delay: Duration.zero,
      ).board();

      expect(board.totalSaved.currency, Currency.tzs);
      for (final progress in board.active) {
        expect(progress.saved.currency, progress.goal.target.currency);
      }
    });
  });
}
