/// Date formatting for the transaction list.
///
/// Dates, not money — Rule 1 is about amounts, and a calendar has to be
/// worked out somewhere. Kept pure and injectable (`today` is passed in,
/// never read from the clock) so the labels can be tested without the
/// suite behaving differently depending on the day it runs.
abstract final class DateLabels {
  const DateLabels._();

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

  static const List<String> _shortMonths = [
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

  /// Midnight on the day [moment] falls in, so two timestamps on the same
  /// day group together regardless of the hour.
  static DateTime dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// A group heading: "Today", "Yesterday", or the full date.
  ///
  /// The two relative labels earn their place because almost everything a
  /// user records is recent, and "Today" is read faster than a date they
  /// then have to compare against today's.
  static String groupLabel(DateTime date, DateTime today) {
    final day = dayOf(date);
    final reference = dayOf(today);
    final difference = reference.difference(day).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    // Same year needs no year; a different one does, or a January entry
    // reads as this January.
    if (day.year == reference.year) {
      return '${day.day} ${_months[day.month - 1]}';
    }
    return '${day.day} ${_months[day.month - 1]} ${day.year}';
  }

  /// A compact date for a transaction row: "Today", "Yesterday", "23 Nov".
  static String rowLabel(DateTime date, DateTime today) {
    final day = dayOf(date);
    final reference = dayOf(today);
    final difference = reference.difference(day).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (day.year == reference.year) {
      return '${day.day} ${_shortMonths[day.month - 1]}';
    }
    return '${day.day} ${_shortMonths[day.month - 1]} ${day.year}';
  }

  /// An unambiguous date for the detail sheet and the form, where the
  /// reader wants the actual day rather than a relative one.
  static String full(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// A date range, for the filter chip.
  static String range(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'Any date';
    if (from != null && to == null) return 'From ${short(from)}';
    if (from == null && to != null) return 'Until ${short(to)}';
    return '${short(from!)} – ${short(to!)}';
  }

  static String short(DateTime date) =>
      '${date.day} ${_shortMonths[date.month - 1]}';
}
