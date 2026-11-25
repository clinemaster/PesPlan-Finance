import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import 'app_button.dart';

/// The surface everything sits on.
///
/// A white fill, a hairline border and a soft shadow. The border matters more
/// than the shadow: at these shadow weights, a card on the off-white canvas
/// is defined mostly by its edge, which stays crisp on cheap LCD panels where
/// a subtle shadow disappears entirely.
///
/// Pass [onTap] to make the whole card a target — the ink ripple is clipped
/// to the card's radius, and the tap area is the full surface rather than the
/// text inside it.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.background,
    this.borderColor,
    this.showShadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? background;
  final Color? borderColor;
  final bool showShadow;

  /// Groups the card's contents under one spoken label, instead of a screen
  /// reader walking every fragment separately. Worth setting on summary cards
  /// where the parts only make sense together.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: background ?? context.colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: borderColor ?? finance.border),
        boxShadow: showShadow ? finance.cardShadow : null,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardAll,
          child: content,
        ),
      );
    }

    if (semanticLabel != null) {
      // excludeSemantics: the label is a complete sentence describing the
      // card, so the children must not also be announced one fragment at a
      // time after it.
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        excludeSemantics: true,
        child: content,
      );
    }

    return content;
  }
}

/// A heading above a group of content, with an optional action on the right.
///
/// The action is a text button rather than an icon: "See all" is
/// self-explanatory where a chevron is not, and it gives a 48px-tall target
/// without extra padding.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header: true tells a screen reader this begins a section, so
                // it can be reached with heading navigation.
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.titleSection.copyWith(
                      color: finance.textPrimary,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            AppButton.text(
              label: actionLabel!,
              onPressed: onAction,
              size: AppButtonSize.small,
            ),
        ],
      ),
    );
  }
}

/// A hairline rule.
///
/// Thin and one step off the surface. Never dashed — a dashed rule reads as
/// "projected" or "threshold", which means something specific in a finance
/// UI and should not be spent on decoration.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.height, this.indent = 0});

  final double? height;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: context.finance.border,
      thickness: AppStroke.hairline,
      height: height ?? AppSpacing.lg,
      indent: indent,
      endIndent: indent,
    );
  }
}

/// Wraps a chart with its title, an optional legend and a table-view toggle.
///
/// ## Why the toggle is part of the container
///
/// A chart conveys values through position and colour, which excludes anyone
/// using a screen reader and anyone who cannot separate two hues. Every chart
/// in LifePilot therefore ships a text equivalent, and putting the affordance
/// in the shared container is what makes that automatic rather than something
/// each screen remembers.
///
/// Pass [table] to enable it. The chart itself is marked as an image with
/// [semanticLabel] so a reader hears what it shows and is pointed at the
/// table.
class ChartContainer extends StatefulWidget {
  const ChartContainer({
    required this.title,
    required this.chart,
    required this.semanticLabel,
    super.key,
    this.subtitle,
    this.legend,
    this.table,
    this.height = 200,
  });

  final String title;
  final String? subtitle;
  final Widget chart;

  /// Spoken description of what the chart shows.
  final String semanticLabel;

  final Widget? legend;

  /// The text equivalent. When provided, a "Table" toggle appears.
  final Widget? table;

  final double height;

  @override
  State<ChartContainer> createState() => _ChartContainerState();
}

class _ChartContainerState extends State<ChartContainer> {
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: AppTypography.titleCard.copyWith(
                          color: finance.textPrimary,
                        ),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: finance.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.table != null)
                AppButton.text(
                  label: _showTable ? 'Chart' : 'Table',
                  onPressed: () => setState(() => _showTable = !_showTable),
                  size: AppButtonSize.small,
                  semanticLabel: _showTable
                      ? 'Show chart instead of table'
                      : 'Show values as a table',
                ),
            ],
          ),
          if (widget.legend != null) ...[
            const SizedBox(height: AppSpacing.md),
            widget.legend!,
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_showTable && widget.table != null)
            widget.table!
          else
            SizedBox(
              height: widget.height,
              // The chart is one image to assistive tech; its values are
              // reachable through the table view.
              child: Semantics(
                label: widget.semanticLabel,
                image: true,
                child: ExcludeSemantics(child: widget.chart),
              ),
            ),
        ],
      ),
    );
  }
}

/// A legend entry: a mark in the series colour plus its name in ink.
///
/// The mark mirrors the chart: a rectangle for bars and areas, a short stroke
/// for lines. Text always stays in an ink colour — a light series hue is
/// illegible as text, and identity comes from the mark beside the label.
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({
    required this.color,
    required this.label,
    super.key,
    this.isLine = false,
  });

  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 14 : 10,
          height: isLine ? 2.5 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 1.5 : 2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: context.finance.textSecondary,
          ),
        ),
      ],
    );
  }
}
