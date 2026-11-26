/// The time-of-day half of the dashboard greeting.
///
/// A pure function of the hour so it can be tested at every boundary without
/// waiting for the afternoon. The clock itself is injected (see
/// `clockProvider`), because a widget that reads `DateTime.now()` directly
/// is a widget whose greeting cannot be tested at all.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  // Afternoon ends at 17:00 rather than 18:00: by five it is dusk in Dar es
  // Salaam year-round, since equatorial sunset barely moves.
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
