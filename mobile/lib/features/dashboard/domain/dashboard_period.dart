/// The window the dashboard summarises.
///
/// The two presets cover almost every question a user actually asks ("how am
/// I doing this month?", "how was the year?"). Custom exists for the rest,
/// and carries its own dates so the rest of the app never has to ask which
/// preset a custom range resembles.
class DashboardPeriod {
  const DashboardPeriod._(this.kind, {this.start, this.end});

  const DashboardPeriod.thisMonth() : this._(PeriodKind.thisMonth);

  const DashboardPeriod.thisYear() : this._(PeriodKind.thisYear);

  /// A user-chosen range. Both ends are inclusive dates.
  const DashboardPeriod.custom({required DateTime start, required DateTime end})
    : this._(PeriodKind.custom, start: start, end: end);

  final PeriodKind kind;

  /// Set only when [kind] is [PeriodKind.custom].
  final DateTime? start;
  final DateTime? end;

  /// The label on the selector chip.
  String get label => switch (kind) {
    PeriodKind.thisMonth => 'This month',
    PeriodKind.thisYear => 'This year',
    PeriodKind.custom => 'Custom',
  };

  /// A fuller description for the caption under the summary, so a user can
  /// tell at a glance which window the figures belong to.
  String describe() => switch (kind) {
    PeriodKind.thisMonth => 'This month',
    PeriodKind.thisYear => 'This year',
    PeriodKind.custom =>
      start == null || end == null
          ? 'Custom range'
          : '${_shortDate(start!)} – ${_shortDate(end!)}',
  };

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  @override
  bool operator ==(Object other) =>
      other is DashboardPeriod &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);

  @override
  String toString() => 'DashboardPeriod(${describe()})';
}

enum PeriodKind { thisMonth, thisYear, custom }
