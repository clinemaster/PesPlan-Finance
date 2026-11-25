import 'package:material_ui/material_ui.dart';

import '../core/design_system/design_system.dart';
import 'showcase_data.dart';
import 'showcase_sections.dart';

/// Internal review harness for the design system.
///
/// Not production navigation: nothing in the app routes here. It exists so the
/// whole visual language can be reviewed in one place, and so golden tests
/// have a stable target that fails when a token changes unintentionally.
///
/// Five tabs rather than one long scroll, because each tab is a reviewable
/// unit and captures as a single screenshot.
class DesignSystemShowcase extends StatefulWidget {
  const DesignSystemShowcase({super.key});

  @override
  State<DesignSystemShowcase> createState() => _DesignSystemShowcaseState();
}

class _DesignSystemShowcaseState extends State<DesignSystemShowcase> {
  ThemeMode _mode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifePilot Design System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: ShowcaseHome(onToggleTheme: _toggleTheme, mode: _mode),
    );
  }
}

/// The tabbed showcase body. Separated from the [MaterialApp] so widget tests
/// can mount it inside their own theme without a nested app.
class ShowcaseHome extends StatelessWidget {
  const ShowcaseHome({
    super.key,
    this.onToggleTheme,
    this.mode = ThemeMode.light,
  });

  final VoidCallback? onToggleTheme;
  final ThemeMode mode;

  static const List<String> tabs = [
    'Colour',
    'Type',
    'Components',
    'Finance',
    'Charts',
  ];

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Design System'),
          actions: [
            if (onToggleTheme != null)
              AppIconButton(
                icon: mode == ThemeMode.light
                    ? AppIcons.hidden
                    : AppIcons.visible,
                tooltip: mode == ThemeMode.light
                    ? 'Switch to dark theme'
                    : 'Switch to light theme',
                onPressed: onToggleTheme,
              ),
            const SizedBox(width: AppSpacing.sm),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: context.colors.primary,
            unselectedLabelColor: finance.textSecondary,
            indicatorColor: context.colors.primary,
            labelStyle: AppTypography.label,
            tabs: [for (final tab in tabs) Tab(text: tab)],
          ),
        ),
        body: const TabBarView(
          children: [
            ColourSection(),
            TypeSection(),
            ComponentsSection(),
            FinanceSection(),
            ChartsSection(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          items: ShowcaseData.navItems,
          currentIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );
  }
}
