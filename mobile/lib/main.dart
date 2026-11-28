import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/credential_store.dart';
import 'core/storage/key_value_store.dart';
import 'features/onboarding/presentation/providers/auth_providers.dart';

/// Entry point.
///
/// Storage is opened before the first frame and handed to the provider
/// scope ready to read. That is deliberate: controllers restore themselves
/// synchronously inside `build()`, so a user with a session goes straight
/// to their dashboard instead of watching the welcome screen appear and
/// then vanish.
///
/// The cost is a slightly longer gap before the first frame. Reading one
/// preferences file is a few milliseconds, which is cheaper than a visible
/// flash of the wrong screen.
///
/// ## Two stores, on purpose
///
/// Preferences hold what the app shows; the keystore holds what proves who
/// the user is. Nothing in the app can write a credential to the first,
/// because the two have different interfaces and only one of them is handed
/// to the auth feature's vault. See `CredentialStore` for why that is worth
/// an extra provider.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesStore(preferences),
        ),
        credentialStoreProvider.overrideWithValue(
          SecureCredentialStore.standard(),
        ),
      ],
      child: const _Bootstrap(),
    ),
  );
}

/// The app, plus the one thing that has to happen after it starts.
///
/// ## Why the session refresh lives here and not in `LifePilotApp`
///
/// A returning user's stored credential expired while the app was closed, so
/// it is replaced in the background on launch. That is a real-provider
/// concern: it needs the platform channels, and it would run in every widget
/// test if it were in the app widget, where tests boot `LifePilotApp`
/// directly. Keeping it in the entry point means the production path does it
/// and the test path does not have to pretend to.
///
/// Nothing waits for it. The session on screen came from storage and stands
/// whatever the provider says — `SessionRestore` has the argument for why a
/// refresh that fails must never return someone to a sign-in screen.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    ref.read(authControllerProvider.notifier).refreshSession();
  }

  @override
  Widget build(BuildContext context) => const LifePilotApp();
}
