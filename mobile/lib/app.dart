import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/design_system/design_system.dart';
import 'core/storage/key_value_store.dart';
import 'core/router/app_router.dart';

/// Which theme the app renders in.
///
/// [ThemeMode.system] is the default because a finance app is opened in
/// every lighting condition and the device already knows which the user
/// prefers. Settings will expose an override in a later phase; the
/// controller exists now so that screen has something to write to.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String _key = 'settings.themeMode';

  @override
  ThemeMode build() {
    final stored = ref.read(keyValueStoreProvider).getString(_key);
    return ThemeMode.values
            .where((mode) => mode.name == stored)
            .firstOrNull ??
        ThemeMode.system;
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(keyValueStoreProvider).setString(_key, mode.name);
  }

  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// The application root.
///
/// Deliberately thin: themes come from [AppTheme], routing from
/// [routerProvider], and this widget only wires them together. Anything that
/// grows here is usually something that belongs in a feature.
class LifePilotApp extends ConsumerWidget {
  const LifePilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LifePilot Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
