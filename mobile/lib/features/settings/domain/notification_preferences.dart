/// The kinds of thing the app would tell you about.
///
/// ## Named by what they are for, not by when they fire
///
/// "Budget alerts" is a thing a user wants or does not want; "daily job
/// at 09:00" is an implementation detail they should never have to
/// reason about. The scheduling arrives with notifications themselves;
/// the choice is the part that belongs to the user.
enum NotificationChannel {
  budgetAlerts,
  savingsReminders,
  weeklySummary,
  monthlySummary,
  productNews;

  String get title => switch (this) {
    NotificationChannel.budgetAlerts => 'Budget alerts',
    NotificationChannel.savingsReminders => 'Savings reminders',
    NotificationChannel.weeklySummary => 'Weekly summary',
    NotificationChannel.monthlySummary => 'Monthly summary',
    NotificationChannel.productNews => 'Product news',
  };

  String get description => switch (this) {
    NotificationChannel.budgetAlerts =>
      'When a budget is close to its limit, or past it.',
    NotificationChannel.savingsReminders =>
      'A nudge to put something aside for your goals.',
    NotificationChannel.weeklySummary =>
      'What came in and what went out, once a week.',
    NotificationChannel.monthlySummary =>
      'The month in one message, with how it compared.',
    NotificationChannel.productNews =>
      'New features and changes to LifePilot. Never marketing from '
          'anyone else.',
  };

  /// Whether this starts switched on.
  ///
  /// The two that act on the user's own money default on; the summaries
  /// and the product news do not. An app that arrives shouting is an app
  /// whose notifications get turned off wholesale in the first week.
  bool get onByDefault => switch (this) {
    NotificationChannel.budgetAlerts => true,
    NotificationChannel.savingsReminders => true,
    NotificationChannel.weeklySummary => false,
    NotificationChannel.monthlySummary => false,
    NotificationChannel.productNews => false,
  };

  /// Which group the setting sits in.
  NotificationGroup get group => switch (this) {
    NotificationChannel.budgetAlerts ||
    NotificationChannel.savingsReminders => NotificationGroup.yourMoney,
    NotificationChannel.weeklySummary ||
    NotificationChannel.monthlySummary => NotificationGroup.summaries,
    NotificationChannel.productNews => NotificationGroup.everythingElse,
  };
}

enum NotificationGroup {
  yourMoney,
  summaries,
  everythingElse;

  String get title => switch (this) {
    NotificationGroup.yourMoney => 'Your money',
    NotificationGroup.summaries => 'Summaries',
    NotificationGroup.everythingElse => 'Everything else',
  };

  String get subtitle => switch (this) {
    NotificationGroup.yourMoney =>
      'Things that need you to do something about them.',
    NotificationGroup.summaries => 'A look back, on a schedule you choose.',
    NotificationGroup.everythingElse => 'About the app itself.',
  };

  List<NotificationChannel> get channels => [
    for (final channel in NotificationChannel.values)
      if (channel.group == this) channel,
  ];
}

/// Which notifications the user wants.
class NotificationPreferences {
  const NotificationPreferences(this.enabled);

  /// What a new account starts with.
  factory NotificationPreferences.initial() => NotificationPreferences({
    for (final channel in NotificationChannel.values)
      if (channel.onByDefault) channel,
  });

  final Set<NotificationChannel> enabled;

  bool isOn(NotificationChannel channel) => enabled.contains(channel);

  int get onCount => enabled.length;

  bool get allOff => enabled.isEmpty;

  NotificationPreferences withChannel(
    NotificationChannel channel, {
    required bool isOn,
  }) => NotificationPreferences(
    {...enabled, if (isOn) channel}
      ..removeWhere((existing) => !isOn && existing == channel),
  );

  /// The summary line on the settings hub.
  String get summary {
    if (allOff) return 'All off';
    if (onCount == NotificationChannel.values.length) return 'All on';
    return '$onCount of ${NotificationChannel.values.length} on';
  }
}
