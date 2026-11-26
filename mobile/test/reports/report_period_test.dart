import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/reports/domain/report_period.dart';

/// A Thursday, so weekday maths is exercised away from the boundaries.
final DateTime now = DateTime(2026, 11, 26, 15, 30);

void main() {
  group('windows', () {
    test('a day covers itself', () {
      final period = ReportPeriod.today(now);
      expect(period.start, DateTime(2026, 11, 26));
      expect(period.end, DateTime(2026, 11, 26));
      expect(period.dayCount, 1);
    });

    test('a week runs Monday to Sunday around the anchor', () {
      final period = ReportPeriod.week(now);
      expect(period.start, DateTime(2026, 11, 23));
      expect(period.end, DateTime(2026, 11, 29));
      expect(period.dayCount, 7);
    });

    test('a month covers its own length', () {
      expect(ReportPeriod.month(now).start, DateTime(2026, 11));
      expect(ReportPeriod.month(now).end, DateTime(2026, 11, 30));
      expect(ReportPeriod.month(now).dayCount, 30);
    });

    test('February is handled without a lookup table', () {
      expect(ReportPeriod.monthOf(2026, 2).end, DateTime(2026, 2, 28));
      // 2028 is a leap year.
      expect(ReportPeriod.monthOf(2028, 2).end, DateTime(2028, 2, 29));
      expect(ReportPeriod.monthOf(2028, 2).dayCount, 29);
    });

    test('a year runs January to December', () {
      expect(ReportPeriod.year(now).start, DateTime(2026));
      expect(ReportPeriod.year(now).end, DateTime(2026, 12, 31));
    });

    test('a custom range covers exactly what was chosen, inclusive', () {
      final period = ReportPeriod.custom(
        from: DateTime(2026, 3, 1, 9),
        to: DateTime(2026, 3, 10, 18),
      );
      expect(period.start, DateTime(2026, 3));
      expect(period.end, DateTime(2026, 3, 10));
      expect(period.dayCount, 10);
    });
  });

  group('stepping', () {
    test('a month steps back across a year boundary', () {
      final january = ReportPeriod.monthOf(2026, 1);
      expect(january.previous().start, DateTime(2025, 12));
      expect(january.previous().title(), 'December 2025');
    });

    test('a week steps by seven days', () {
      final period = ReportPeriod.week(now).previous();
      expect(period.start, DateTime(2026, 11, 16));
    });

    test('a year steps by one', () {
      expect(ReportPeriod.year(now).previous().title(), '2025');
    });

    test('a custom range does not step', () {
      final period = ReportPeriod.custom(
        from: DateTime(2026, 3),
        to: DateTime(2026, 3, 10),
      );
      expect(period.previous(), period);
      expect(period.next(), period);
      expect(period.canGoNext(now), isFalse);
    });
  });

  group('the future is out of bounds', () {
    test('the current month cannot step forward', () {
      // A window that has not started can only report zero, and letting
      // someone walk into 2031 to find nothing looks broken, not empty.
      expect(ReportPeriod.month(now).canGoNext(now), isFalse);
    });

    test('a past month can', () {
      expect(ReportPeriod.monthOf(2026, 9).canGoNext(now), isTrue);
    });

    test('the current year cannot step forward', () {
      expect(ReportPeriod.year(now).canGoNext(now), isFalse);
      expect(ReportPeriod.yearOf(2025).canGoNext(now), isTrue);
    });

    test('today cannot step forward', () {
      expect(ReportPeriod.today(now).canGoNext(now), isFalse);
      expect(
        ReportPeriod.today(DateTime(2026, 11, 25)).canGoNext(now),
        isTrue,
      );
    });
  });

  group('in progress', () {
    test('the current month is, a finished one is not', () {
      expect(ReportPeriod.month(now).isInProgress(now), isTrue);
      expect(ReportPeriod.monthOf(2026, 10).isInProgress(now), isFalse);
    });

    test('the current year is', () {
      expect(ReportPeriod.year(now).isInProgress(now), isTrue);
      expect(ReportPeriod.yearOf(2024).isInProgress(now), isFalse);
    });
  });

  group('titles', () {
    test('name the window concretely', () {
      expect(ReportPeriod.monthOf(2026, 11).title(), 'November 2026');
      expect(ReportPeriod.yearOf(2026).title(), '2026');
      expect(ReportPeriod.today(now).title(), '26 November 2026');
      expect(ReportPeriod.week(now).title(), '23 Nov – 29 Nov');
    });
  });

  group('custom range validation', () {
    test('accepts an ordinary range', () {
      expect(
        validateCustomRange(
          start: DateTime(2026, 3),
          end: DateTime(2026, 4),
          now: now,
        ),
        isNull,
      );
    });

    test('rejects a start after the end', () {
      expect(
        validateCustomRange(
          start: DateTime(2026, 4),
          end: DateTime(2026, 3),
          now: now,
        ),
        CustomRangeError.startAfterEnd,
      );
    });

    test('rejects an end in the future', () {
      expect(
        validateCustomRange(
          start: DateTime(2026, 11),
          end: DateTime(2027),
          now: now,
        ),
        CustomRangeError.endInFuture,
      );
    });

    test('accepts a range ending today', () {
      expect(
        validateCustomRange(
          start: DateTime(2026, 11),
          end: now,
          now: now,
        ),
        isNull,
      );
    });

    test('rejects an absurdly long range', () {
      expect(
        validateCustomRange(
          start: DateTime(2000),
          end: now,
          now: now,
        ),
        CustomRangeError.tooLong,
      );
    });

    test('every error carries a message a user could act on', () {
      for (final error in CustomRangeError.values) {
        expect(error.message, isNotEmpty);
      }
    });
  });
}
