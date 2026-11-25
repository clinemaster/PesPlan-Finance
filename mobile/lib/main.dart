import 'package:material_ui/material_ui.dart';

import 'showcase/design_system_showcase.dart';

/// Phase 02 entry point.
///
/// The app currently launches the **design system showcase**, because Phase 02
/// delivers the visual language and no product screens. Phase 03 replaces
/// this with the real root widget and routing; the showcase then stays
/// reachable for internal review but leaves the production navigation tree.
void main() {
  runApp(const DesignSystemShowcase());
}
