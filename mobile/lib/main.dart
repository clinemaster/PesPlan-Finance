import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/key_value_store.dart';

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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesStore(preferences),
        ),
      ],
      child: const LifePilotApp(),
    ),
  );
}
