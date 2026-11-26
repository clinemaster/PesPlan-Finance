import 'package:material_ui/material_ui.dart';

import '../../../../core/design_system/design_system.dart';

/// The LifePilot Finance mark.
///
/// A navigation needle inside a rounded square: "pilot" is the half of the
/// name that distinguishes the product, and a compass needle says steering
/// without resorting to the coins and piggy banks every finance app already
/// uses.
///
/// Drawn from theme colours rather than an image so it inverts correctly in
/// dark mode and stays sharp at every size.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.all(Radius.circular(size * 0.28)),
        boxShadow: context.isDarkMode
            ? AppElevation.darkMd
            : AppElevation.md,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.navigation_rounded,
        size: size * 0.52,
        color: context.colors.onPrimary,
      ),
    );
  }
}

/// The product name set as a wordmark.
///
/// "LifePilot" carries the weight and "Finance" rides beneath it, so the
/// brand reads first and the category second.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.centered = true});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'LifePilot',
          style: AppTypography.displayMedium.copyWith(
            color: finance.textPrimary,
          ),
        ),
        Text(
          'FINANCE',
          style: AppTypography.labelSmall.copyWith(
            color: context.colors.primary,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
