/// How long a goal has left, in words.
///
/// Dates, not money — Rule 1 is about amounts, and a calendar has to be
/// worked out somewhere. Kept pure and injectable (`today` is passed in,
/// never read from the clock) so the labels can be tested without the
/// suite behaving differently depending on the day it runs.
abstract final class GoalTiming {
  /// Days between two dates, ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// "12 days to go", "3 months to go", "Date passed".
  ///
  /// Deliberately coarse past a month: nobody saving for a laptop in
  /// March needs to know it is 114 days away, and the rounder number is
  /// the one they can act on.
  static String? remaining(DateTime? targetDate, DateTime today) {
    if (targetDate == null) return null;

    final days = daysBetween(today, targetDate);
    if (days < 0) return 'Date passed';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 31) return '$days days to go';

    final months = (days / 30.44).round();
    if (months <= 1) return 'About a month to go';
    if (months < 12) return '$months months to go';

    final years = (days / 365.25).round();
    if (years <= 1) return 'About a year to go';
    return '$years years to go';
  }

  /// The dashboard's one-line context for a goal.
  ///
  /// A target date is the more useful fact when there is one; otherwise
  /// the month it started says how long this has been going.
  static String caption(
    DateTime? targetDate,
    DateTime createdAt,
    DateTime today,
  ) {
    if (targetDate != null) {
      return 'Target: ${monthName(targetDate.month)} ${targetDate.year}';
    }
    return 'Started in ${monthName(createdAt.month)}';
  }

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
}
