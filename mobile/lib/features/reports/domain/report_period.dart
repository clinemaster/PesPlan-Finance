import '../../transactions/domain/date_labels.dart';

/// Which window a report covers.
enum ReportPeriodKind {
  today,
  week,
  month,
  year,
  custom;

  String get label => switch (this) {
    ReportPeriodKind.today => 'Day',
    ReportPeriodKind.week => 'Week',
    ReportPeriodKind.month => 'Month',
    ReportPeriodKind.year => 'Year',
    ReportPeriodKind.custom => 'Custom',
  };
}

/// A reporting window, anchored to a date.
///
/// ## Anchored rather than relative
///
/// "This month" is a starting point, not the definition: a user who taps
/// back three times is looking at August, and the period has to remember
/// that. So the kind says how wide the window is and the anchor says where
/// it sits, which makes [previous] and [next] ordinary date arithmetic
/// instead of a special case per screen.
///
/// Pure date handling, no money — Rule 1 is about amounts.
class ReportPeriod {
  const ReportPeriod._(this.kind, this.anchor, {this.from, this.to});

  factory ReportPeriod.today(DateTime now) =>
      ReportPeriod._(ReportPeriodKind.today, DateLabels.dayOf(now));

  factory ReportPeriod.week(DateTime now) =>
      ReportPeriod._(ReportPeriodKind.week, DateLabels.dayOf(now));

  factory ReportPeriod.month(DateTime now) =>
      ReportPeriod._(ReportPeriodKind.month, DateTime(now.year, now.month));

  factory ReportPeriod.year(DateTime now) =>
      ReportPeriod._(ReportPeriodKind.year, DateTime(now.year));

  /// A specific month, for drilling in from the annual report.
  factory ReportPeriod.monthOf(int year, int month) =>
      ReportPeriod._(ReportPeriodKind.month, DateTime(year, month));

  factory ReportPeriod.yearOf(int year) =>
      ReportPeriod._(ReportPeriodKind.year, DateTime(year));

  factory ReportPeriod.custom({
    required DateTime from,
    required DateTime to,
  }) => ReportPeriod._(
    ReportPeriodKind.custom,
    DateLabels.dayOf(from),
    from: DateLabels.dayOf(from),
    to: DateLabels.dayOf(to),
  );

  final ReportPeriodKind kind;

  /// Where the window sits. Normalised per kind: the day for a day, the
  /// week's own day for a week, the first of the month, the first of
  /// January.
  final DateTime anchor;

  final DateTime? from;
  final DateTime? to;

  /// First day covered, inclusive.
  DateTime get start => switch (kind) {
    ReportPeriodKind.today => anchor,
    // Weeks run Monday to Sunday: the ISO convention, and the one a
    // working week matches in the launch market.
    ReportPeriodKind.week => anchor.subtract(
      Duration(days: anchor.weekday - DateTime.monday),
    ),
    ReportPeriodKind.month => DateTime(anchor.year, anchor.month),
    ReportPeriodKind.year => DateTime(anchor.year),
    ReportPeriodKind.custom => from!,
  };

  /// Last day covered, inclusive.
  DateTime get end => switch (kind) {
    ReportPeriodKind.today => anchor,
    ReportPeriodKind.week => start.add(const Duration(days: 6)),
    // Day zero of the next month is the last day of this one, which
    // handles February and leap years without a table.
    ReportPeriodKind.month => DateTime(anchor.year, anchor.month + 1, 0),
    ReportPeriodKind.year => DateTime(anchor.year, 12, 31),
    ReportPeriodKind.custom => to!,
  };

  /// How many days the window spans, inclusive of both ends.
  int get dayCount => end.difference(start).inDays + 1;

  /// The window shifted back one step. Custom ranges do not step.
  ReportPeriod previous() => switch (kind) {
    ReportPeriodKind.today => ReportPeriod._(
      kind,
      anchor.subtract(const Duration(days: 1)),
    ),
    ReportPeriodKind.week => ReportPeriod._(
      kind,
      anchor.subtract(const Duration(days: 7)),
    ),
    ReportPeriodKind.month => ReportPeriod._(
      kind,
      DateTime(anchor.year, anchor.month - 1),
    ),
    ReportPeriodKind.year => ReportPeriod._(kind, DateTime(anchor.year - 1)),
    ReportPeriodKind.custom => this,
  };

  ReportPeriod next() => switch (kind) {
    ReportPeriodKind.today => ReportPeriod._(
      kind,
      anchor.add(const Duration(days: 1)),
    ),
    ReportPeriodKind.week => ReportPeriod._(
      kind,
      anchor.add(const Duration(days: 7)),
    ),
    ReportPeriodKind.month => ReportPeriod._(
      kind,
      DateTime(anchor.year, anchor.month + 1),
    ),
    ReportPeriodKind.year => ReportPeriod._(kind, DateTime(anchor.year + 1)),
    ReportPeriodKind.custom => this,
  };

  /// Whether stepping forward lands anywhere a report can exist.
  ///
  /// A window that has not started yet can only ever report zero, and a
  /// screen that lets a user walk into 2031 and find nothing looks broken
  /// rather than empty. A partly-elapsed window is allowed — this month is
  /// worth reading on the 3rd.
  bool canGoNext(DateTime now) {
    if (kind == ReportPeriodKind.custom) return false;
    return !next().start.isAfter(DateLabels.dayOf(now));
  }

  /// True when the window has not finished yet, so its totals are partial.
  bool isInProgress(DateTime now) {
    final today = DateLabels.dayOf(now);
    return !end.isBefore(today) && !start.isAfter(today);
  }

  /// The concrete window, spelled out: "November 2026", "2026",
  /// "24 – 30 Nov".
  String title() => switch (kind) {
    ReportPeriodKind.today => DateLabels.full(anchor),
    ReportPeriodKind.week => '${DateLabels.short(start)} – '
        '${DateLabels.short(end)}',
    ReportPeriodKind.month => '${_months[anchor.month - 1]} ${anchor.year}',
    ReportPeriodKind.year => '${anchor.year}',
    ReportPeriodKind.custom =>
      '${DateLabels.short(start)} – ${DateLabels.short(end)}'
          '${start.year == end.year ? ' ${end.year}' : ''}',
  };

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String monthName(int month) => _months[month - 1];

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.anchor == anchor &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, anchor, from, to);

  @override
  String toString() => 'ReportPeriod(${kind.name}, ${title()})';
}

/// Why a custom range was rejected.
///
/// Returned rather than thrown: an invalid range is something the user is
/// in the middle of choosing, not an exceptional condition.
enum CustomRangeError {
  startAfterEnd,
  endInFuture,
  tooLong;

  String get message => switch (this) {
    CustomRangeError.startAfterEnd => 'The start date must come before the end date',
    CustomRangeError.endInFuture => 'Pick an end date of today or earlier',
    CustomRangeError.tooLong => 'Ranges are limited to five years',
  };
}

/// Checks a user-chosen range before it becomes a [ReportPeriod].
CustomRangeError? validateCustomRange({
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  final from = DateLabels.dayOf(start);
  final to = DateLabels.dayOf(end);

  if (from.isAfter(to)) return CustomRangeError.startAfterEnd;
  if (to.isAfter(DateLabels.dayOf(now))) return CustomRangeError.endInFuture;
  if (to.difference(from).inDays > 365 * 5) return CustomRangeError.tooLong;
  return null;
}
