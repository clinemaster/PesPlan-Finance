/// A timezone, as a user picks one.
///
/// ## A short list, not the IANA database
///
/// Six hundred zone names in a dropdown is a worse answer than a dozen
/// cities covering the markets this app serves: the point of the setting
/// is that "today" and "this month" end when the user's day ends, and a
/// nearby city with the same offset does that correctly. The full
/// database arrives when the backend needs it for scheduling.
class AppTimezone {
  const AppTimezone({
    required this.id,
    required this.city,
    required this.offsetHours,
  });

  /// IANA identifier, so the stored value is already the right shape for
  /// a server that speaks tz.
  final String id;

  final String city;

  /// Hours from UTC. Whole hours only — the half-hour zones are not in
  /// the launch markets, and a fake half-hour entry would be worse than
  /// none.
  final int offsetHours;

  String get label {
    final sign = offsetHours >= 0 ? '+' : '−';
    return '$city (UTC$sign${offsetHours.abs()})';
  }

  static const AppTimezone eastAfrica = AppTimezone(
    id: 'Africa/Dar_es_Salaam',
    city: 'Dar es Salaam',
    offsetHours: 3,
  );

  static const List<AppTimezone> supported = [
    eastAfrica,
    AppTimezone(id: 'Africa/Nairobi', city: 'Nairobi', offsetHours: 3),
    AppTimezone(id: 'Africa/Kampala', city: 'Kampala', offsetHours: 3),
    AppTimezone(id: 'Africa/Lagos', city: 'Lagos', offsetHours: 1),
    AppTimezone(
      id: 'Africa/Johannesburg',
      city: 'Johannesburg',
      offsetHours: 2,
    ),
    AppTimezone(id: 'Europe/London', city: 'London', offsetHours: 0),
    AppTimezone(id: 'Europe/Berlin', city: 'Berlin', offsetHours: 1),
    AppTimezone(id: 'America/New_York', city: 'New York', offsetHours: -5),
    AppTimezone(id: 'Asia/Dubai', city: 'Dubai', offsetHours: 4),
    AppTimezone(id: 'UTC', city: 'UTC', offsetHours: 0),
  ];

  static const AppTimezone initial = eastAfrica;

  static AppTimezone fromId(String? id) {
    for (final zone in supported) {
      if (zone.id == id) return zone;
    }
    return initial;
  }

  @override
  bool operator ==(Object other) => other is AppTimezone && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
