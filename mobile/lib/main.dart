import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

/// Phase 03 entry point.
///
/// The app now launches the real root widget and its router, which starts at
/// the welcome screen. The Phase 02 design system showcase has not gone away
/// — it is a route (`/showcase`), reachable from the home placeholder — so
/// the visual language stays reviewable without being what the app opens on.
void main() {
  runApp(const ProviderScope(child: LifePilotApp()));
}
