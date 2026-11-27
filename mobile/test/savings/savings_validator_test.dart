import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/savings/domain/goal_timing.dart';
import 'package:lifepilot_finance/features/savings/domain/savings_validator.dart';

final DateTime now = DateTime(2026, 11, 26, 15, 30);

void main() {
  group('name', () {
    test('is required', () {
      expect(SavingsValidator.name(null), 'Give this goal a name');
      expect(SavingsValidator.name('   '), 'Give this goal a name');
    });

    test('is accepted once given', () {
      expect(SavingsValidator.name('Emergency fund'), isNull);
    });

    test('is capped', () {
      expect(
        SavingsValidator.name('x' * (SavingsValidator.maxNameLength + 1)),
        contains('under'),
      );
      expect(
        SavingsValidator.name('x' * SavingsValidator.maxNameLength),
        isNull,
      );
    });
  });

  group('target', () {
    test('is required', () {
      expect(SavingsValidator.target(null), 'Enter a target amount');
    });

    test('must be positive', () {
      // A goal with nothing to reach has no progress to show, and the
      // figure is almost always half-typed.
      expect(SavingsValidator.target(0), 'Enter an amount greater than zero');
      expect(
        SavingsValidator.target(-100),
        'Enter an amount greater than zero',
      );
    });

    test('accepts a plausible figure, and refuses a runaway one', () {
      expect(SavingsValidator.target(2000000), isNull);
      expect(
        SavingsValidator.target(SavingsValidator.maxMinorUnits + 1),
        contains('too large'),
      );
    });
  });

  group('opening amount', () {
    test('is optional', () {
      expect(SavingsValidator.initialAmount(null, 500000), isNull);
      expect(SavingsValidator.initialAmount(0, 500000), isNull);
    });

    test('is accepted up to the target', () {
      expect(SavingsValidator.initialAmount(500000, 500000), isNull);
      expect(SavingsValidator.initialAmount(100000, 500000), isNull);
    });

    test('cannot exceed the target', () {
      // A goal created already finished is a completion the app never
      // saw happen, with no history behind it.
      expect(
        SavingsValidator.initialAmount(600000, 500000),
        'That is more than the target',
      );
    });
  });

  group('target date', () {
    test('is optional', () {
      expect(SavingsValidator.targetDate(null, now), isNull);
    });

    test('must not be in the past', () {
      expect(
        SavingsValidator.targetDate(DateTime(2026, 11, 25), now),
        'Choose a date in the future',
      );
    });

    test('today is allowed, since the day is not over', () {
      expect(SavingsValidator.targetDate(DateTime(2026, 11, 26), now), isNull);
    });

    test('a date ahead is allowed', () {
      expect(SavingsValidator.targetDate(DateTime(2027, 3, 31), now), isNull);
    });

    test('refuses a date beyond what this app plans for', () {
      expect(
        SavingsValidator.targetDate(DateTime(2099), now),
        contains('further ahead'),
      );
    });
  });

  group('contribution', () {
    test('is required and positive', () {
      expect(SavingsValidator.contribution(null), 'Enter an amount');
      expect(
        SavingsValidator.contribution(0),
        'Enter an amount greater than zero',
      );
      expect(SavingsValidator.contribution(50000), isNull);
    });
  });

  group('withdrawal', () {
    test('is required and positive', () {
      expect(SavingsValidator.withdrawal(null, 100000), 'Enter an amount');
      expect(
        SavingsValidator.withdrawal(0, 100000),
        'Enter an amount greater than zero',
      );
    });

    test('cannot exceed what the goal holds', () {
      // The money was never there to take, so there is no state in which
      // this is a withdrawal rather than a mistake.
      expect(
        SavingsValidator.withdrawal(150000, 100000),
        'That is more than this goal holds',
      );
    });

    test('taking exactly the balance is allowed', () {
      expect(SavingsValidator.withdrawal(100000, 100000), isNull);
    });

    test('an empty goal says so, rather than quoting a limit of zero', () {
      expect(
        SavingsValidator.withdrawal(1000, 0),
        'There is nothing in this goal to take out',
      );
    });
  });

  group('movement date', () {
    test('is required', () {
      expect(SavingsValidator.movementDate(null, now), 'Choose a date');
    });

    test('cannot be in the future', () {
      // The user is recording something that happened, not scheduling
      // one.
      expect(
        SavingsValidator.movementDate(DateTime(2026, 11, 27), now),
        'Choose today or a past date',
      );
    });

    test('today and the past are fine', () {
      expect(
        SavingsValidator.movementDate(DateTime(2026, 11, 26), now),
        isNull,
      );
      expect(SavingsValidator.movementDate(DateTime(2026), now), isNull);
    });
  });

  group('canSaveGoal', () {
    bool save({
      String? name = 'Emergency fund',
      int? target = 500000,
      int? initial,
      String note = '',
      DateTime? date,
      bool editing = false,
    }) => SavingsValidator.canSaveGoal(
      name: name,
      targetMinorUnits: target,
      initialMinorUnits: initial,
      description: note,
      targetDate: date,
      now: now,
      isEditing: editing,
    );

    test('needs a name and a target', () {
      expect(save(), isTrue);
      expect(save(name: ''), isFalse);
      expect(save(target: null), isFalse);
      expect(save(target: 0), isFalse);
    });

    test('refuses an opening amount above the target when creating', () {
      expect(save(initial: 900000), isFalse);
      expect(save(initial: 400000), isTrue);
    });

    test('ignores the opening amount when editing', () {
      // The edit form does not collect one: an existing goal's balance is
      // its movements, and an amount box there would look like a way to
      // overwrite them.
      expect(save(initial: 900000, editing: true), isTrue);
    });

    test('refuses a past target date and a too-long note', () {
      expect(save(date: DateTime(2020)), isFalse);
      expect(save(note: 'x' * 200), isFalse);
    });
  });

  group('time remaining', () {
    final today = DateTime(2026, 11, 26);

    test('reads nothing when there is no date', () {
      expect(GoalTiming.remaining(null, today), isNull);
    });

    test('counts days close in', () {
      expect(GoalTiming.remaining(DateTime(2026, 11, 26), today), 'Today');
      expect(GoalTiming.remaining(DateTime(2026, 11, 27), today), 'Tomorrow');
      expect(
        GoalTiming.remaining(DateTime(2026, 12, 6), today),
        '10 days to go',
      );
    });

    test('rounds to months further out', () {
      // Nobody saving for a laptop in March needs to know it is 125 days
      // away; the rounder number is the one they can act on.
      expect(
        GoalTiming.remaining(DateTime(2027, 3, 31), today),
        '4 months to go',
      );
    });

    test('rounds to years further out still', () {
      expect(
        GoalTiming.remaining(DateTime(2029, 11, 26), today),
        '3 years to go',
      );
    });

    test('says plainly when the date has passed', () {
      expect(GoalTiming.remaining(DateTime(2026, 10), today), 'Date passed');
    });
  });

  group('the dashboard caption', () {
    final today = DateTime(2026, 11, 26);

    test('names the target month when there is one', () {
      expect(
        GoalTiming.caption(DateTime(2027, 3, 31), DateTime(2026, 9), today),
        'Target: March 2027',
      );
    });

    test('falls back to when the goal started', () {
      expect(
        GoalTiming.caption(null, DateTime(2026, 6, 12), today),
        'Started in June',
      );
    });
  });
}
