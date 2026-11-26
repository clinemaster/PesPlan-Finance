import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/design_system.dart';

/// The app's permanent frame: five destinations and the bar that switches
/// between them.
///
/// ## Why the shell owns no content
///
/// It renders whatever branch go_router hands it. Keeping the frame free of
/// screen logic is what lets each tab keep its own navigation stack — open a
/// transaction, switch to Budgets, come back, and the transaction is still
/// open — which a single shared Navigator cannot do.
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  /// The current branch and the means to switch branches.
  final StatefulNavigationShell navigationShell;

  static const List<AppNavItem> destinations = [
    AppNavItem(icon: AppIcons.home, label: 'Home'),
    AppNavItem(icon: AppIcons.transactions, label: 'Activity'),
    AppNavItem(icon: AppIcons.budgets, label: 'Budgets'),
    AppNavItem(icon: AppIcons.goals, label: 'Goals'),
    AppNavItem(icon: AppIcons.assistant, label: 'Assistant'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        items: destinations,
        currentIndex: navigationShell.currentIndex,
        onChanged: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on returns to the root of that
          // tab. It is the standard escape hatch from somewhere deep, and
          // without it a user four screens into Activity has to press back
          // four times.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
