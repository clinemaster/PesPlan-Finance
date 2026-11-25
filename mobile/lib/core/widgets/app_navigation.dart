import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';

/// The app bar.
///
/// Flat, on the page background rather than a raised surface: a shadowed bar
/// over a light canvas adds a horizontal band that competes with the content
/// below it. The title is left-aligned, which is easier to scan and leaves the
/// right side for at most two actions.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    super.key,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle == null ? kToolbarHeight : kToolbarHeight + 18);

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppBar(
      leading: showBack
          ? IconButton(
              icon: const Icon(AppIcons.back),
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : leading,
      automaticallyImplyLeading: showBack,
      titleSpacing: showBack || leading != null ? 0 : AppSpacing.lg,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.titleScreen.copyWith(
                color: finance.textPrimary,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: finance.textSecondary,
              ),
            ),
        ],
      ),
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

/// One destination in the bottom bar.
class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.badgeCount});

  final IconData icon;
  final String label;

  /// Optional count, e.g. unreviewed transactions.
  final int? badgeCount;
}

/// Bottom navigation.
///
/// ## Why labels are always shown
///
/// Material's default hides labels for unselected destinations, which assumes
/// the user already recognises the icons. For an audience that has never used
/// a finance app, an unlabelled icon is a guess — so labels stay visible, and
/// the bar is 68px tall to fit them comfortably at a large text scale.
///
/// Three to five destinations. Beyond five, targets get too narrow for a
/// thumb and the labels truncate.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    super.key,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    assert(
      items.length >= 2 && items.length <= 5,
      'Bottom navigation takes 2-5 destinations; got ${items.length}.',
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.finance.border)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex.clamp(0, items.length - 1),
        onDestinationSelected: onChanged,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: item.badgeCount == null || item.badgeCount == 0
                  ? Icon(item.icon)
                  : Badge.count(
                      count: item.badgeCount!,
                      child: Icon(item.icon),
                    ),
              label: item.label,
              tooltip: item.label,
            ),
        ],
      ),
    );
  }
}
