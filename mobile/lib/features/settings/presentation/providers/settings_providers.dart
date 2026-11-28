import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../../core/time/clock.dart';
import '../../data/settings_store.dart';
import '../../domain/app_timezone.dart';
import '../../domain/notification_preferences.dart';
import '../../domain/subscription.dart';

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(keyValueStoreProvider)),
);

/// Which notifications the user wants.
///
/// Restored synchronously in `build`, like every other controller here:
/// a settings screen that paints the defaults and then corrects itself a
/// frame later looks like it forgot.
class NotificationPreferencesController
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() =>
      ref.watch(settingsStoreProvider).readNotifications();

  void set(NotificationChannel channel, {required bool isOn}) {
    state = state.withChannel(channel, isOn: isOn);
    ref.read(settingsStoreProvider).writeNotifications(state);
  }

  /// One switch for the lot, for someone who wants quiet.
  void setAll({required bool isOn}) {
    state = NotificationPreferences(
      isOn ? NotificationChannel.values.toSet() : const {},
    );
    ref.read(settingsStoreProvider).writeNotifications(state);
  }
}

final notificationPreferencesProvider =
    NotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

/// Which timezone the user's day runs on.
class TimezoneController extends Notifier<AppTimezone> {
  @override
  AppTimezone build() => ref.watch(settingsStoreProvider).readTimezone();

  void select(AppTimezone zone) {
    state = zone;
    ref.read(settingsStoreProvider).writeTimezone(zone);
  }
}

final timezoneProvider = NotifierProvider<TimezoneController, AppTimezone>(
  TimezoneController.new,
);

/// The plan the app is pretending the account is on.
///
/// ## No billing, and no entitlement
///
/// Nothing is charged, nothing is verified, and no feature anywhere
/// reads this to decide what the user may do. It exists so the premium
/// presentation can be reviewed on a device, and every screen that shows
/// it says as much. Phase 20 replaces it with a real store integration.
class SubscriptionController extends Notifier<Subscription> {
  @override
  Subscription build() => ref.watch(settingsStoreProvider).readSubscription();

  /// Switches the mock plan to premium.
  void upgrade() {
    final now = ref.read(clockProvider)();

    state = Subscription(
      plan: Plan.premium,
      // A month out, so the renewal line has something to show. It is a
      // date on a mock, not a commitment.
      renewsOn: DateTime(now.year, now.month + 1, now.day),
      isMockUpgrade: true,
    );
    ref.read(settingsStoreProvider).writeSubscription(state);
  }

  void cancel() {
    state = Subscription.free;
    ref.read(settingsStoreProvider).writeSubscription(state);
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionController, Subscription>(
      SubscriptionController.new,
    );
