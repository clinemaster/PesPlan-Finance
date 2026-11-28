import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/app_timezone.dart';
import '../domain/notification_preferences.dart';
import '../domain/subscription.dart';

/// The settings that are the user's own choices.
///
/// Name, country, currency and language already travel with the profile
/// from setup, and the theme has its own key from Phase 02. What is kept
/// here is the rest: which notifications are wanted, which timezone the
/// user's day runs on, and — for review only — which plan the app is
/// pretending the account is on.
class SettingsStore {
  const SettingsStore(this._store);

  final KeyValueStore _store;

  static const String _notificationsKey = 'settings.notifications';
  static const String _timezoneKey = 'settings.timezone';
  static const String _planKey = 'settings.plan';

  NotificationPreferences readNotifications() {
    final raw = _store.getString(_notificationsKey);
    // Absent is not "all off": a new account gets the defaults, and only
    // a written value means the user has actually chosen.
    if (raw == null) return NotificationPreferences.initial();

    try {
      final names = (jsonDecode(raw) as List<dynamic>).cast<String>();
      return NotificationPreferences({
        for (final channel in NotificationChannel.values)
          if (names.contains(channel.name)) channel,
      });
    } on Object {
      return NotificationPreferences.initial();
    }
  }

  Future<void> writeNotifications(NotificationPreferences preferences) =>
      _store.setString(
        _notificationsKey,
        jsonEncode([for (final channel in preferences.enabled) channel.name]),
      );

  AppTimezone readTimezone() =>
      AppTimezone.fromId(_store.getString(_timezoneKey));

  Future<void> writeTimezone(AppTimezone zone) =>
      _store.setString(_timezoneKey, zone.id);

  /// The mock plan.
  ///
  /// Stored so the premium presentation survives a relaunch during
  /// review. It is not an entitlement and nothing reads it to unlock
  /// anything.
  Subscription readSubscription() {
    final raw = _store.getString(_planKey);
    if (raw != 'premium') return Subscription.free;

    return const Subscription(plan: Plan.premium, isMockUpgrade: true);
  }

  Future<void> writeSubscription(Subscription subscription) =>
      _store.setString(_planKey, subscription.plan.name);

  Future<void> clear() async {
    await _store.remove(_notificationsKey);
    await _store.remove(_timezoneKey);
    await _store.remove(_planKey);
  }
}
