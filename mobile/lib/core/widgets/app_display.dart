import 'package:material_ui/material_ui.dart';

import '../design_system/theme/context_ext.dart';
import '../design_system/tokens/app_icons.dart';
import '../design_system/tokens/app_motion.dart';
import '../design_system/tokens/app_shape.dart';
import '../design_system/tokens/app_spacing.dart';
import '../design_system/tokens/app_typography.dart';
import '../money/money.dart';

/// How prominent an amount is.
enum MoneySize { hero, large, medium, small }

/// Renders an amount.
///
/// ## This widget decides the colour, so screens do not
///
/// Money in is green, money out is red, zero is neutral — and that mapping
/// lives in `FinanceColors.amountColor` rather than at the call site, so a
/// screen cannot accidentally render an expense in green. Pass
/// [colorBySign] = false where the amount is a neutral total and colour would
/// add noise.
///
/// ## Accessibility
///
/// The visible string is compact ("-TSh 12,500"), which a screen reader can
/// announce as an ambiguous run of symbols. [Money.semanticLabel] is used
/// instead, so the user hears "12,500 TZS out".
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    super.key,
    this.size = MoneySize.medium,
    this.colorBySign = true,
    this.showSign = false,
    this.color,
    this.abbreviate = false,
    this.alignment = Alignment.centerLeft,
  });

  /// Convenience for a raw minor-unit integer in the default currency.
  MoneyText.cents(
    int minorUnits, {
    Key? key,
    MoneySize size = MoneySize.medium,
    bool colorBySign = true,
    bool showSign = false,
    Color? color,
    bool abbreviate = false,
    Alignment alignment = Alignment.centerLeft,
  }) : this(
         Money(minorUnits),
         key: key,
         size: size,
         colorBySign: colorBySign,
         showSign: showSign,
         color: color,
         abbreviate: abbreviate,
         alignment: alignment,
       );

  final Money money;
  final MoneySize size;

  /// Colour by direction. Off gives the primary ink colour.
  final bool colorBySign;

  /// Force a `+` on positive values.
  final bool showSign;

  /// Explicit override, used where the amount sits on a coloured fill.
  final Color? color;

  final bool abbreviate;

  /// Which edge the figure hugs once it has been scaled to fit. Right-aligned
  /// columns of amounts should pass [Alignment.centerRight].
  final Alignment alignment;

  TextStyle get _style => switch (size) {
    MoneySize.hero => AppTypography.amountHero,
    MoneySize.large => AppTypography.amountLarge,
    MoneySize.medium => AppTypography.amountMedium,
    MoneySize.small => AppTypography.amountSmall,
  };

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final resolved =
        color ??
        (colorBySign
            ? finance.amountColor(money.minorUnits)
            : finance.textPrimary);

    return Semantics(
      label: money.semanticLabel,
      excludeSemantics: true,
      // An amount shrinks to fit; it never truncates.
      //
      // At a large text scale a figure like "TSh 3,200,000" can outgrow its
      // card, and an ellipsis there ("TSh 3,2…") destroys the one piece of
      // information the user opened the app for. A label may be clipped; a
      // number may not. BoxFit.scaleDown only acts when space is short, so
      // nothing changes at the default text size.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          money.format(showSign: showSign, abbreviate: abbreviate),
          style: _style.copyWith(color: resolved),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// Badge tone. Each maps to a semantic pair, never to a raw colour.
enum BadgeTone { neutral, primary, income, expense, savings, warning }

/// A small label for a count, a state or a category.
///
/// Filled with a tint and inked with the matching readable colour — never a
/// saturated fill with white text at this size, which is hard to read and
/// visually loud for something this small.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    super.key,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final colors = context.colors;

    final (Color background, Color foreground) = switch (tone) {
      BadgeTone.neutral => (finance.surfaceMuted, finance.textSecondary),
      BadgeTone.primary => (colors.primaryContainer, colors.onPrimaryContainer),
      BadgeTone.income => (finance.incomeSurface, finance.incomeText),
      BadgeTone.expense => (finance.expenseSurface, finance.expenseText),
      BadgeTone.savings => (finance.savingsSurface, finance.savingsText),
      BadgeTone.warning => (finance.warningSurface, finance.warningText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: foreground,
              fontWeight: AppTypography.medium,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { success, warning, error, info, pending }

/// A state, stated three ways: icon, colour and words.
///
/// Colour alone cannot carry a status — roughly one in twelve men cannot
/// separate the red from the green — so this widget always renders an icon
/// and a label too. There is deliberately no option to hide the label.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    required this.label,
    required this.tone,
    super.key,
    this.compact = false,
  });

  final String label;
  final StatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    final (IconData icon, Color color, Color background) = switch (tone) {
      StatusTone.success => (
        AppIcons.success,
        finance.successText,
        finance.successSurface,
      ),
      StatusTone.warning => (
        AppIcons.warning,
        finance.warningText,
        finance.warningSurface,
      ),
      StatusTone.error => (
        AppIcons.error,
        finance.expenseText,
        finance.expenseSurface,
      ),
      StatusTone.info => (AppIcons.info, finance.infoText, finance.infoSurface),
      StatusTone.pending => (
        AppIcons.pending,
        finance.textSecondary,
        finance.surfaceMuted,
      ),
    };

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.sm, color: color),
        const SizedBox(width: AppSpacing.xs),
        // Flexible: the label must give way rather than overflow. English
        // "Over budget" fits almost anywhere; a translation or a large text
        // scale may not, and this row is often nested inside an Expanded
        // column on a narrow phone.
        Flexible(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: AppTypography.medium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (compact) return row;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: row,
    );
  }
}

/// A circular avatar with initials, for a person or an account.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.label,
    super.key,
    this.size = 40,
    this.background,
    this.foreground,
  });

  final String label;
  final double size;
  final Color? background;
  final Color? foreground;

  /// First letters of the first two words — "Alicia London" gives "AL".
  String get _initials {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: AppTypography.label.copyWith(
            color: foreground ?? colors.onPrimaryContainer,
            fontWeight: AppTypography.semibold,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

/// A category's icon in a tinted round container.
///
/// Tinted rather than saturated: a list of ten transactions each with a solid
/// coloured circle is visually exhausting, and the icon is an identifier
/// rather than a status.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    required this.category,
    super.key,
    this.size = 40,
    this.tint,
    this.iconColor,
  });

  final String category;
  final double size;
  final Color? tint;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Semantics(
      label: category,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint ?? finance.surfaceMuted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.forCategory(category),
          size: size * 0.5,
          color: iconColor ?? finance.textSecondary,
        ),
      ),
    );
  }
}

/// A horizontal progress bar, used for budgets and goals.
///
/// The fill carries severity: accent while comfortable, amber when close to
/// the limit, red when over. The track is a tint of the fill's own hue rather
/// than a neutral grey, so the state reads across the whole bar rather than
/// only in the filled part.
///
/// [value] is a ratio supplied by the caller — this widget does not compute
/// it from amounts. Values above 1.0 clamp the fill but are still reported in
/// the semantics, so "over budget" is never silently hidden.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    super.key,
    this.height = AppSpacing.sm,
    this.color,
    this.trackColor,
    this.semanticLabel,
    this.animate = true,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final clamped = value.clamp(0.0, 1.0);

    final fill =
        color ??
        (value > 1.0
            ? finance.expense
            : value >= 0.8
            ? finance.warning
            : context.colors.primary);

    final track =
        trackColor ??
        Color.alphaBlend(fill.withValues(alpha: 0.16), context.colors.surface);

    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            Container(height: height, color: track),
            if (animate)
              _ProgressFill(value: clamped, height: height, color: fill)
            else
              FractionallySizedBox(
                widthFactor: clamped,
                child: Container(height: height, color: fill),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animates a progress fill from empty to [value].
class _ProgressFill extends StatelessWidget {
  const _ProgressFill({
    required this.value,
    required this.height,
    required this.color,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      builder: (context, animated, _) => FractionallySizedBox(
        widthFactor: animated,
        child: Container(height: height, color: color),
      ),
    );
  }
}

/// A circular progress ring, for a single headline ratio such as a savings
/// goal. Shows a label in the middle so the figure is readable without
/// interpreting the arc.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    required this.value,
    super.key,
    this.size = 96,
    this.strokeWidth = AppStroke.ring,
    this.color,
    this.centerLabel,
    this.centerCaption,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? centerLabel;
  final String? centerCaption;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final clamped = value.clamp(0.0, 1.0);
    final fill =
        color ??
        (value > 1.0
            ? finance.expense
            : value >= 0.8
            ? finance.warning
            : context.colors.primary);

    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()}%',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                value: clamped,
                color: fill,
                track: Color.alphaBlend(
                  fill.withValues(alpha: 0.16),
                  context.colors.surface,
                ),
                strokeWidth: strokeWidth,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (centerLabel != null)
                  Text(
                    centerLabel!,
                    style: AppTypography.amountLarge.copyWith(
                      color: finance.textPrimary,
                      fontSize: size * 0.22,
                    ),
                  ),
                if (centerCaption != null)
                  Text(
                    centerCaption!,
                    style: AppTypography.caption.copyWith(
                      color: finance.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Starts at 12 o'clock and runs clockwise, which is how people read a
    // dial.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966,
      6.283185307179586 * value,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
