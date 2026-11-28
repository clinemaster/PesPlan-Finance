import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/core/router/routes.dart';
import 'package:lifepilot_finance/core/storage/key_value_store.dart';
import 'package:lifepilot_finance/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lifepilot_finance/features/settings/domain/notification_preferences.dart';
import 'package:lifepilot_finance/features/settings/domain/subscription.dart';
import 'package:lifepilot_finance/features/settings/presentation/providers/settings_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  group('the hub', () {
    testWidgets('shows who is signed in and on which plan', (tester) async {
      await SettingsHarness.pump(tester);

      expect(find.text('Amina Hassan'), findsOneWidget);
      expect(find.text('amina.hassan@gmail.com'), findsOneWidget);
      expect(find.text('Free'), findsWidgets);
      expect(find.textContaining('Tanzania · TZS'), findsOneWidget);
    });

    testWidgets('every section is reachable from one screen', (tester) async {
      await SettingsHarness.pump(tester);

      for (final section in [
        'Preferences',
        'Notifications',
        'Security & privacy',
        'Subscription',
        'Help & support',
        'Account',
      ]) {
        await SettingsHarness.scrollTo(tester, find.text(section));
        expect(find.text(section), findsWidgets, reason: section);
      }
    });

    testWidgets('rows say what they are currently set to', (tester) async {
      // A row that says "Appearance" and nothing else makes the user
      // open it to find out what it is set to.
      await SettingsHarness.pump(tester);

      expect(find.text('English · TZS'), findsOneWidget);
      expect(find.text('Match system'), findsOneWidget);
      expect(find.text('2 of 5 on'), findsOneWidget);
    });
  });

  group('the profile', () {
    testWidgets('opens pre-filled from the account', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsProfile);

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Amina Hassan'), findsWidgets);

      // The email card sits under the editable fields. On a demo build the
      // badge says so: the address did not come from Google, because this
      // build never asked Google anything.
      await SettingsHarness.scrollTo(tester, find.text('Demo account'));
      expect(find.text('amina.hassan@gmail.com'), findsOneWidget);
      expect(find.text('Demo account'), findsOneWidget);
    });

    testWidgets('credits Google for the email on a configured build', (
      tester,
    ) async {
      await SettingsHarness.pump(
        tester,
        route: Routes.settingsProfile,
        config: SettingsHarness.googleConfigured,
      );

      await SettingsHarness.scrollTo(tester, find.text('From Google'));
      expect(find.text('From Google'), findsOneWidget);
      expect(find.text('Demo account'), findsNothing);
    });

    testWidgets('a new name is saved and shown on the hub', (tester) async {
      final harness = await SettingsHarness.pump(tester);
      await SettingsHarness.open(tester, 'Amina Hassan');

      await tester.enterText(find.byType(TextField).first, 'Amina H. Mushi');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Profile updated'), findsOneWidget);
      expect(
        harness.container.read(onboardingControllerProvider).draft!.name,
        'Amina H. Mushi',
      );
      expect(find.text('Amina H. Mushi'), findsWidgets);
    });

    testWidgets('an empty name is refused, and nothing is saved', (
      tester,
    ) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsProfile,
      );

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Your profile'), findsOneWidget);
      expect(
        harness.container.read(onboardingControllerProvider).draft!.name,
        'Amina Hassan',
      );
    });

    testWidgets('a bad phone number is refused', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsProfile);

      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Profile updated'), findsNothing);
    });

    testWidgets('the phone number is optional', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsProfile,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Profile updated'), findsOneWidget);
      expect(
        harness.container.read(onboardingControllerProvider).draft!.phone,
        anyOf(isNull, isEmpty),
      );
    });

    testWidgets('cancelling keeps what was there', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsProfile,
      );

      await tester.enterText(find.byType(TextField).first, 'Someone else');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(onboardingControllerProvider).draft!.name,
        'Amina Hassan',
      );
    });

    testWidgets('a photo is honestly a placeholder', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsProfile);

      expect(find.text('Your initials, for now'), findsOneWidget);
      expect(find.textContaining('Uploading a photo arrives'), findsOneWidget);
    });
  });

  group('preferences', () {
    testWidgets('language, country, currency, timezone and theme are all '
        'there', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPreferences);

      for (final label in [
        'Language',
        'Country',
        'Currency',
        'Timezone',
        'Appearance',
      ]) {
        await SettingsHarness.scrollTo(tester, find.text(label));
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('choosing Kiswahili is saved, and says what it does not do', (
      tester,
    ) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsPreferences,
      );

      expect(
        find.textContaining('The interface is English for now'),
        findsOneWidget,
      );

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiswahili').last);
      await tester.pumpAndSettle();

      expect(
        harness.container
            .read(onboardingControllerProvider)
            .draft!
            .language
            .label,
        'Kiswahili',
      );
    });

    testWidgets('currency can be set to any supported one', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsPreferences,
      );

      await SettingsHarness.scrollTo(tester, find.text('Currency'));
      await tester.tap(find.textContaining('TZS · ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('EUR · ').last);
      await tester.pumpAndSettle();

      expect(
        harness.container
            .read(onboardingControllerProvider)
            .draft!
            .currency
            .code,
        'EUR',
      );
    });

    testWidgets('changing country suggests its currency', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsPreferences,
      );

      await tester.tap(find.text('Tanzania').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kenya').last);
      await tester.pumpAndSettle();

      final profile = harness.container
          .read(onboardingControllerProvider)
          .draft!;
      expect(profile.country.name, 'Kenya');
      expect(profile.currency.code, 'KES');
    });

    testWidgets('the timezone is saved', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsPreferences,
      );

      await SettingsHarness.scrollTo(tester, find.text('Timezone'));
      await tester.tap(find.textContaining('Dar es Salaam').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Nairobi').last);
      await tester.pumpAndSettle();

      expect(harness.container.read(timezoneProvider).city, 'Nairobi');
    });

    testWidgets('the theme changes the app, not just the setting', (
      tester,
    ) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPreferences);

      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match system').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  group('notifications', () {
    testWidgets('are grouped, described, and default sensibly', (tester) async {
      // An app that arrives shouting is an app whose notifications get
      // turned off wholesale in the first week.
      await SettingsHarness.pump(tester, route: Routes.settingsNotifications);

      expect(find.text('Your money'), findsOneWidget);
      expect(find.text('Summaries'), findsOneWidget);
      expect(find.text('Budget alerts'), findsOneWidget);
      expect(
        find.textContaining('When a budget is close to its limit'),
        findsOneWidget,
      );
    });

    testWidgets('a switch is kept', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsNotifications,
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final preferences = harness.container.read(
        notificationPreferencesProvider,
      );
      expect(preferences.isOn(NotificationChannel.budgetAlerts), isFalse);
    });

    testWidgets('all of them can be turned off and on again', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsNotifications,
      );

      await tester.tap(find.text('All off'));
      await tester.pumpAndSettle();
      expect(
        harness.container.read(notificationPreferencesProvider).allOff,
        isTrue,
      );

      await tester.tap(find.text('All on'));
      await tester.pumpAndSettle();
      expect(
        harness.container.read(notificationPreferencesProvider).onCount,
        NotificationChannel.values.length,
      );
    });

    testWidgets('says plainly that nothing is sent yet', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsNotifications);

      expect(find.textContaining('Nothing is sent yet'), findsOneWidget);
    });

    testWidgets('choices survive a relaunch', (tester) async {
      final store = InMemoryKeyValueStore();

      final first = await SettingsHarness.pump(
        tester,
        route: Routes.settingsNotifications,
        store: store,
      );
      await tester.tap(find.text('All off'));
      await tester.pumpAndSettle();
      expect(
        first.container.read(notificationPreferencesProvider).allOff,
        isTrue,
      );

      final second = await SettingsHarness.pump(
        tester,
        route: Routes.settingsNotifications,
        store: store,
      );

      expect(
        second.container.read(notificationPreferencesProvider).allOff,
        isTrue,
      );
    });
  });

  group('security and privacy', () {
    testWidgets('explains the sign-in and offers no password', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPrivacy);

      expect(find.text('Signed in as'), findsOneWidget);
      expect(find.text('No password to remember'), findsOneWidget);
    });

    testWidgets('a demo build says the sign-in is a stand-in', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPrivacy);

      expect(find.textContaining('signs in with a stand-in'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
      expect(
        find.text('Your sign-in is kept in the phone keystore'),
        findsNothing,
      );
    });

    testWidgets('a configured build names Google and the keystore', (
      tester,
    ) async {
      // The one piece of security on this screen that is already real, on a
      // screen where the app lock below it is not.
      await SettingsHarness.pump(
        tester,
        route: Routes.settingsPrivacy,
        config: SettingsHarness.googleConfigured,
      );

      expect(find.text('Google'), findsOneWidget);
      expect(
        find.text('Your sign-in is kept in the phone keystore'),
        findsOneWidget,
      );
      expect(find.textContaining('signs in with a stand-in'), findsNothing);
    });

    testWidgets('the lock switches are present and inert', (tester) async {
      // A lock that looks enabled and does not lock is worse than none.
      await SettingsHarness.pump(tester, route: Routes.settingsPrivacy);

      await SettingsHarness.scrollTo(tester, find.text('Locking the app'));
      for (final switchWidget in tester.widgetList<Switch>(
        find.byType(Switch),
      )) {
        expect(switchWidget.onChanged, isNull);
        expect(switchWidget.value, isFalse);
      }
    });

    testWidgets('export says what it will do, and does not do it', (
      tester,
    ) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPrivacy);

      await SettingsHarness.open(tester, 'Export your data');

      expect(
        find.textContaining('Nothing is written or sent today'),
        findsOneWidget,
      );
    });

    testWidgets('deleting asks first, and then deletes nothing', (
      tester,
    ) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsPrivacy,
      );

      await SettingsHarness.open(tester, 'Delete account');
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Delete account').last);
      await tester.pumpAndSettle();

      expect(find.text('Nothing was deleted'), findsOneWidget);
      // Still signed in, with the profile intact.
      expect(
        harness.container.read(onboardingControllerProvider).draft,
        isNotNull,
      );
    });

    testWidgets('cancelling the deletion says nothing at all', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsPrivacy);

      await SettingsHarness.open(tester, 'Delete account');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing was deleted'), findsNothing);
    });
  });

  group('the subscription', () {
    testWidgets('opens on the free plan, with no price anywhere', (
      tester,
    ) async {
      await SettingsHarness.pump(tester, route: Routes.settingsSubscription);

      expect(find.text('You are on the free plan.'), findsOneWidget);
      expect(find.textContaining('Prices are not set'), findsOneWidget);
    });

    testWidgets('compares the plans line by line', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.settingsSubscription);

      await SettingsHarness.scrollTo(tester, find.text('What Premium adds'));
      expect(find.text('Assistant questions'), findsOneWidget);
      expect(find.text('20 a day'), findsOneWidget);
      expect(find.text('200 a day'), findsOneWidget);
    });

    testWidgets('says what the free plan gives, not what it lacks', (
      tester,
    ) async {
      // A table of crosses says "you are missing out" and little else.
      await SettingsHarness.pump(tester, route: Routes.settingsSubscription);

      await SettingsHarness.scrollTo(tester, find.text('On every plan'));
      expect(find.text('Unlimited'), findsWidgets);
    });

    testWidgets('upgrading is confirmed, labelled, and takes no money', (
      tester,
    ) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsSubscription,
      );

      await SettingsHarness.scrollTo(
        tester,
        find.text('Try Premium (review only)'),
      );
      await tester.tap(find.text('Try Premium (review only)'));
      await tester.pumpAndSettle();

      expect(find.text('Switch to Premium?'), findsOneWidget);
      expect(find.textContaining('No payment is taken'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Switch').last);
      await tester.pumpAndSettle();

      expect(harness.container.read(subscriptionProvider).plan, Plan.premium);
      expect(
        harness.container.read(subscriptionProvider).isMockUpgrade,
        isTrue,
      );
      expect(find.text('Premium switched on for review'), findsOneWidget);
    });

    testWidgets('premium can be switched back off', (tester) async {
      final harness = await SettingsHarness.pump(
        tester,
        route: Routes.settingsSubscription,
      );
      harness.container.read(subscriptionProvider.notifier).upgrade();
      await tester.pumpAndSettle();

      await SettingsHarness.scrollTo(tester, find.text('Switch back to Free'));
      await tester.tap(find.text('Switch back to Free'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Switch back').last);
      await tester.pumpAndSettle();

      expect(harness.container.read(subscriptionProvider).plan, Plan.free);
    });

    testWidgets('restore purchases explains itself rather than pretending', (
      tester,
    ) async {
      await SettingsHarness.pump(tester, route: Routes.settingsSubscription);

      await SettingsHarness.scrollTo(tester, find.text('Restore purchases'));
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nothing to restore'), findsOneWidget);
    });

    testWidgets('the plan shows on the hub once it changes', (tester) async {
      final harness = await SettingsHarness.pump(tester);
      harness.container.read(subscriptionProvider.notifier).upgrade();
      await tester.pumpAndSettle();

      expect(find.text('Premium'), findsWidgets);
    });
  });

  group('help and support', () {
    testWidgets('offers help, contact and legal, with a version', (
      tester,
    ) async {
      await SettingsHarness.pump(tester, route: Routes.settingsHelp);

      for (final row in [
        'Help centre',
        'Common questions',
        'Contact support',
        'Send feedback',
        'Terms of service',
        'Privacy policy',
      ]) {
        await SettingsHarness.scrollTo(tester, find.text(row));
        expect(find.text(row), findsWidgets, reason: row);
      }

      await SettingsHarness.scrollTo(tester, find.text('LifePilot Finance'));
      expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    });

    testWidgets('every link says it is not wired up', (tester) async {
      // A help centre link that goes nowhere is the oldest broken
      // promise in software.
      await SettingsHarness.pump(tester, route: Routes.settingsHelp);

      await SettingsHarness.open(tester, 'Help centre');

      expect(find.text('Not wired up in this build.'), findsOneWidget);
    });
  });

  group('the account', () {
    testWidgets('signing out asks first', (tester) async {
      await SettingsHarness.pump(tester);

      await SettingsHarness.open(tester, 'Sign out');

      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.textContaining('stay on this device'), findsOneWidget);
    });

    testWidgets('cancelling keeps the user signed in', (tester) async {
      final harness = await SettingsHarness.pump(tester);

      await SettingsHarness.open(tester, 'Sign out');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(onboardingControllerProvider).draft,
        isNotNull,
      );
    });
  });

  group('navigation', () {
    testWidgets('the dashboard avatar opens settings', (tester) async {
      await SettingsHarness.pump(tester, route: Routes.home);

      await tester.tap(find.bySemanticsLabel('Profile and settings'));
      await tester.pumpAndSettle();

      expect(find.text('Profile & settings'), findsOneWidget);
    });

    testWidgets('each section comes back to the hub', (tester) async {
      await SettingsHarness.pump(tester);

      await SettingsHarness.open(tester, 'Alerts and reminders');
      expect(find.text('Notifications'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Profile & settings'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (name, size) in [
      ('a phone', SettingsHarness.phone),
      ('a small phone', SettingsHarness.smallPhone),
    ]) {
      testWidgets('the hub fits $name', (tester) async {
        await SettingsHarness.pump(tester, size: size);
        await SettingsHarness.scrollTo(tester, find.text('Delete account'));

        expect(tester.takeException(), isNull);
      });

      for (final (label, route) in [
        ('the profile', Routes.settingsProfile),
        ('preferences', Routes.settingsPreferences),
        ('notifications', Routes.settingsNotifications),
        ('security and privacy', Routes.settingsPrivacy),
        ('the subscription', Routes.settingsSubscription),
        ('help', Routes.settingsHelp),
      ]) {
        testWidgets('$label fits $name', (tester) async {
          await SettingsHarness.pump(tester, route: route, size: size);
          await tester.drag(find.byType(ListView).last, const Offset(0, -600));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
