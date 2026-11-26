import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/design_system.dart';

/// A screen that is honest about not existing yet.
///
/// Every tab and quick action the dashboard points at needs somewhere to
/// land. A dead button teaches a reviewer nothing; a screen that names the
/// feature and says when it arrives makes the shape of the finished app
/// legible while it is still being built.
///
/// It deliberately shows no figures. Inventing a balance or a goal here
/// would make a placeholder indistinguishable from a finished screen in a
/// screenshot, which is how fake data ends up in a demo.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
    super.key,
    this.showBack = false,
  });

  final String title;
  final IconData icon;

  /// What this screen will do, in a sentence a non-engineer can read.
  final String message;

  /// True for screens pushed over the shell, which the user expects to
  /// dismiss. Tab roots have nowhere to go back to.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: title,
        showBack: showBack,
        onBack: showBack ? () => context.pop() : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Center(
            child: EmptyState(icon: icon, title: title, message: message),
          ),
        ),
      ),
    );
  }
}
