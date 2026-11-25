/// Chart foundations.
///
/// ## What these are, and are not
///
/// Visual foundations drawn with `CustomPainter`, taking data the caller
/// supplies. They contain **no financial logic**: no totals, no shares, no
/// period comparison. Every value arrives computed (architecture Rule 1), and
/// a chart's only arithmetic is turning a value into a pixel.
///
/// Hand-painted rather than a charting package, for three reasons: no third
/// dependency for six chart types, exact control over the mark specs below,
/// and no library defaults quietly overriding the design system.
///
/// ## The mark rules every chart here follows
///
/// * **Bars cap at 24px thick**, with a 4px rounded data end and a square
///   foot on the baseline. A bar that fills its slot leaves no air and reads
///   as a block.
/// * **Touching marks are separated by a 2px gap in the surface colour**,
///   never by a stroke around them. White does the separating.
/// * **Lines are 2.5px**, round-joined, and **break at missing data** rather
///   than interpolating across it — a month with no records is not a month of
///   zero.
/// * **Markers are >=8px** with a 2px surface ring, so they stay legible where
///   they cross a line.
/// * **Gridlines are solid hairlines** one step off the surface. Never dashed:
///   dashing reads as "projected" or "threshold", which means something
///   specific in a finance chart.
/// * **Text never wears a series colour.** Axis labels and values use ink
///   tokens; identity comes from the coloured mark beside the label.
/// * **Values are labelled selectively** — the peak, the endpoint, the one
///   that matters. A number on every point goes unread.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../design_system/theme/context_ext.dart';
import '../../design_system/tokens/app_shape.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../money/money.dart';
import '../app_display.dart';

/// One point on a line or bar chart.
///
/// A `null` [value] means *no data* and is rendered as a gap, which is
/// different from a zero.
class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  /// Axis label, pre-formatted by the caller (e.g. "Jan").
  final String label;

  /// Minor units, or `null` for no data.
  final int? value;
}

/// A named series with its own colour slot.
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.points,
    required this.color,
  });

  final String name;
  final List<ChartPoint> points;
  final Color color;
}

/// One part of a whole, for the donut.
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  /// Minor units. Non-negative.
  final int value;

  final Color color;
}

/// The tick style, with its font family resolved from the surrounding text
/// style.
///
/// A `TextPainter` built inside a `CustomPainter` does not resolve a null
/// `fontFamily` the way widget text does — it falls back to the engine
/// default, which in a test harness is a placeholder face that draws every
/// glyph as a box. Taking the family from the ambient `DefaultTextStyle`
/// keeps production behaviour identical (still the platform default) while
/// letting a golden test supply a real face.
TextStyle _tickStyle(BuildContext context) {
  return AppTypography.amountTick.copyWith(
    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
    fontFamilyFallback: DefaultTextStyle.of(context).style.fontFamilyFallback,
  );
}

// ---------------------------------------------------------------- line chart

/// A trend over time.
///
/// Takes one or more series on a **single shared axis**. There is deliberately
/// no second y-axis: two scales on one plot invent a correlation that is not
/// in the data, and it is the most common way a finance chart misleads. Two
/// measures of different magnitude belong in two charts.
class AppLineChart extends StatelessWidget {
  const AppLineChart({
    required this.series,
    super.key,
    this.currency = Currency.tzs,
    this.showArea = true,
  });

  final List<ChartSeries> series;
  final Currency currency;

  /// A 10% wash under a single series. Suppressed for multiple series, where
  /// overlapping washes muddy both.
  final bool showArea;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return CustomPaint(
      painter: _LinePainter(
        series: series,
        grid: finance.chartGrid,
        axis: finance.chartAxis,
        tickColor: finance.textTertiary,
        surface: context.colors.surface,
        currency: currency,
        showArea: showArea && series.length == 1,
        tickStyle: _tickStyle(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.grid,
    required this.axis,
    required this.tickColor,
    required this.surface,
    required this.currency,
    required this.showArea,
    required this.tickStyle,
  });

  final List<ChartSeries> series;
  final Color grid;
  final Color axis;
  final Color tickColor;
  final Color surface;
  final Currency currency;
  final bool showArea;
  final TextStyle tickStyle;

  static const double _leftGutter = 44;
  static const double _bottomGutter = 24;
  static const double _topPad = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final pointCount = series.first.points.length;
    if (pointCount == 0) return;

    final peak = _peak();
    final ticks = _niceTicks(peak);
    final scaleMax = ticks.last == 0 ? 1 : ticks.last;

    final plotLeft = _leftGutter;
    final plotRight = size.width;
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomGutter;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    double yOf(int value) => plotBottom - (value / scaleMax) * plotHeight;
    double xOf(int index) => pointCount == 1
        ? plotLeft + plotWidth / 2
        : plotLeft + (plotWidth / (pointCount - 1)) * index;

    // Gridlines and y ticks.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = AppStroke.hairline;

    for (final tick in ticks) {
      final y = yOf(tick);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _drawText(
        canvas,
        Money(
          tick,
          currency: currency,
        ).format(showSymbol: false, abbreviate: true),
        Offset(plotLeft - 8, y),
        align: TextAlign.right,
        anchorRight: true,
        centerVertically: true,
      );
    }

    // Baseline.
    canvas.drawLine(
      Offset(plotLeft, plotBottom),
      Offset(plotRight, plotBottom),
      Paint()
        ..color = axis
        ..strokeWidth = AppStroke.hairline,
    );

    // X labels: first, middle and last only. Twelve rotated labels on a phone
    // is unreadable; the table view carries the rest.
    final labelIndices = <int>{0, pointCount ~/ 2, pointCount - 1};
    for (final index in labelIndices) {
      if (index < 0 || index >= pointCount) continue;
      _drawText(
        canvas,
        series.first.points[index].label,
        Offset(xOf(index), plotBottom + 8),
        align: TextAlign.center,
        centerHorizontally: true,
      );
    }

    // Series, drawn in order so slot 1 sits on top.
    for (final line in series.reversed) {
      final segments = <List<Offset>>[];
      var current = <Offset>[];

      for (var i = 0; i < line.points.length; i++) {
        final value = line.points[i].value;
        if (value == null) {
          // A gap, not a zero: close the current run and start a new one.
          if (current.isNotEmpty) segments.add(current);
          current = <Offset>[];
          continue;
        }
        current.add(Offset(xOf(i), yOf(value)));
      }
      if (current.isNotEmpty) segments.add(current);

      if (showArea) {
        for (final segment in segments) {
          if (segment.length < 2) continue;
          final path = Path()..moveTo(segment.first.dx, plotBottom);
          for (final point in segment) {
            path.lineTo(point.dx, point.dy);
          }
          path
            ..lineTo(segment.last.dx, plotBottom)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = line.color.withValues(alpha: 0.10),
          );
        }
      }

      final strokePaint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.chartLine
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      for (final segment in segments) {
        if (segment.length == 1) {
          // A lone point would draw nothing as a stroke, so mark it.
          _drawMarker(canvas, segment.first, line.color);
          continue;
        }
        final path = Path()..moveTo(segment.first.dx, segment.first.dy);
        for (final point in segment.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, strokePaint);
      }

      // End marker only — one dot per point would be noise.
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        _drawMarker(canvas, segments.last.last, line.color);
      }
    }
  }

  void _drawMarker(Canvas canvas, Offset center, Color color) {
    // 2px ring in the surface colour keeps the dot legible where it crosses
    // a line or another marker.
    canvas
      ..drawCircle(center, 6, Paint()..color = surface)
      ..drawCircle(center, 4.5, Paint()..color = color);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at, {
    TextAlign align = TextAlign.left,
    bool anchorRight = false,
    bool centerHorizontally = false,
    bool centerVertically = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: tickStyle.copyWith(color: tickColor),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();

    var dx = at.dx;
    var dy = at.dy;
    if (anchorRight) dx -= painter.width;
    if (centerHorizontally) dx -= painter.width / 2;
    if (centerVertically) dy -= painter.height / 2;

    painter.paint(canvas, Offset(dx, dy));
  }

  int _peak() {
    var peak = 0;
    for (final line in series) {
      for (final point in line.points) {
        final value = point.value;
        if (value != null && value > peak) peak = value;
      }
    }
    return peak;
  }

  /// Ticks rounded to clean numbers, covering 0..[peak].
  static List<int> _niceTicks(int peak, {int count = 4}) {
    if (peak <= 0) return const [0];
    final raw = peak / count;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    var step = magnitude * 10;
    for (final multiplier in [1, 2, 2.5, 5, 10]) {
      if (multiplier * magnitude >= raw) {
        step = multiplier * magnitude;
        break;
      }
    }
    final stepInt = math.max(1, step.round());
    final top = stepInt * (peak / stepInt).ceil();
    return [for (var v = 0; v <= top; v += stepInt) v];
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.series != series || old.showArea != showArea;
}

// ----------------------------------------------------------------- bar chart

/// Magnitude by category or period.
///
/// Single-series bars are **one colour**, not a colour each: colouring every
/// bar differently double-encodes length as hue and spends the only free
/// channel on information the chart already shows. Pass [series] with more
/// than one entry for grouped bars, where colour genuinely carries identity.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    required this.series,
    super.key,
    this.currency = Currency.tzs,
    this.highlightPeak = true,
  });

  final List<ChartSeries> series;
  final Currency currency;

  /// Labels the tallest bar's value. Selective labelling, by design.
  final bool highlightPeak;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return CustomPaint(
      painter: _BarPainter(
        series: series,
        grid: finance.chartGrid,
        axis: finance.chartAxis,
        tickColor: finance.textTertiary,
        labelColor: finance.textSecondary,
        surface: context.colors.surface,
        currency: currency,
        highlightPeak: highlightPeak,
        tickStyle: _tickStyle(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.series,
    required this.grid,
    required this.axis,
    required this.tickColor,
    required this.labelColor,
    required this.surface,
    required this.currency,
    required this.highlightPeak,
    required this.tickStyle,
  });

  final List<ChartSeries> series;
  final Color grid;
  final Color axis;
  final Color tickColor;
  final Color labelColor;
  final Color surface;
  final Currency currency;
  final bool highlightPeak;
  final TextStyle tickStyle;

  static const double _leftGutter = 44;
  static const double _bottomGutter = 24;

  /// Headroom reserved for the peak's direct label. Without it the tallest
  /// bar reaches the top of the plot and the label is suppressed to avoid
  /// clipping — so the chart would silently lose the one value it labels.
  static const double _topPad = 28;

  static const double _maxBarWidth = 24;
  static const double _gap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final slots = series.first.points.length;
    if (slots == 0) return;

    final peak = _peak();
    final ticks = _LinePainter._niceTicks(peak);
    final scaleMax = ticks.last == 0 ? 1 : ticks.last;

    final plotLeft = _leftGutter;
    final plotBottom = size.height - _bottomGutter;
    final plotTop = _topPad;
    final plotWidth = size.width - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = AppStroke.hairline;

    for (final tick in ticks) {
      final y = plotBottom - (tick / scaleMax) * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      _drawText(
        canvas,
        Money(
          tick,
          currency: currency,
        ).format(showSymbol: false, abbreviate: true),
        Offset(plotLeft - 8, y),
        color: tickColor,
        anchorRight: true,
        centerVertically: true,
      );
    }

    canvas.drawLine(
      Offset(plotLeft, plotBottom),
      Offset(size.width, plotBottom),
      Paint()
        ..color = axis
        ..strokeWidth = AppStroke.hairline,
    );

    final band = plotWidth / slots;
    // Bars never fill their slot: the leftover band is deliberate air.
    final barWidth = math.min(
      _maxBarWidth,
      (band * 0.6 - _gap * (series.length - 1)) / series.length,
    );
    final groupWidth = barWidth * series.length + _gap * (series.length - 1);

    var peakValue = 0;
    var peakCenter = Offset.zero;

    for (var slot = 0; slot < slots; slot++) {
      final bandStart = plotLeft + band * slot;
      final groupStart = bandStart + (band - groupWidth) / 2;

      for (var s = 0; s < series.length; s++) {
        final value = series[s].points[slot].value;
        // No data draws no bar — not a zero-height one.
        if (value == null || value <= 0) continue;

        final height = (value / scaleMax) * plotHeight;
        final left = groupStart + (barWidth + _gap) * s;
        final top = plotBottom - height;

        // 4px rounded cap, square foot on the baseline.
        final radius = math.min(AppRadius.chartBarCap, barWidth / 2);
        canvas.drawPath(
          Path()
            ..moveTo(left, plotBottom)
            ..lineTo(left, top + radius)
            ..quadraticBezierTo(left, top, left + radius, top)
            ..lineTo(left + barWidth - radius, top)
            ..quadraticBezierTo(
              left + barWidth,
              top,
              left + barWidth,
              top + radius,
            )
            ..lineTo(left + barWidth, plotBottom)
            ..close(),
          Paint()..color = series[s].color,
        );

        if (value > peakValue) {
          peakValue = value;
          peakCenter = Offset(left + barWidth / 2, top);
        }
      }

      _drawText(
        canvas,
        series.first.points[slot].label,
        Offset(bandStart + band / 2, plotBottom + 8),
        color: tickColor,
        centerHorizontally: true,
      );
    }

    // One direct label, on the peak, placed above the cap where it cannot be
    // clipped by a short bar.
    if (highlightPeak && peakValue > 0 && peakCenter.dy - plotTop > 10) {
      _drawText(
        canvas,
        Money(
          peakValue,
          currency: currency,
        ).format(showSymbol: false, abbreviate: true),
        Offset(peakCenter.dx, peakCenter.dy - 14),
        color: labelColor,
        centerHorizontally: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    bool anchorRight = false,
    bool centerHorizontally = false,
    bool centerVertically = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: tickStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    var dx = at.dx;
    var dy = at.dy;
    if (anchorRight) dx -= painter.width;
    if (centerHorizontally) dx -= painter.width / 2;
    if (centerVertically) dy -= painter.height / 2;

    painter.paint(canvas, Offset(dx, dy));
  }

  int _peak() {
    var peak = 0;
    for (final s in series) {
      for (final point in s.points) {
        final value = point.value;
        if (value != null && value > peak) peak = value;
      }
    }
    return peak;
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.series != series;
}

// --------------------------------------------------------------- donut chart

/// Part-to-whole, at a glance.
///
/// ## Capped at three coloured segments, on purpose
///
/// In a donut every segment is compared with every other, and that is a much
/// harder colour problem than a bar chart where marks only sit beside their
/// neighbours. Validation of this palette showed blue and purple land
/// **ΔE 1.3 apart under deuteranopia** — indistinguishable — and no ordering
/// of six hues clears the floor with all pairs in play.
///
/// So the honest limit is three. Fold the rest into "Other" (the caller does
/// that, since it involves summing), or use [CategoryBreakdown] instead, which
/// handles many categories safely because it is one colour plus text.
///
/// A centre label carries the headline figure, so the chart is readable
/// without comparing arc lengths — which people are poor at anyway.
class AppDonutChart extends StatelessWidget {
  const AppDonutChart({
    required this.slices,
    super.key,
    this.centerLabel,
    this.centerCaption,
    this.thickness = 22,
  });

  final List<ChartSlice> slices;
  final String? centerLabel;
  final String? centerCaption;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    assert(
      slices.length <= 4,
      'A donut takes at most 4 segments (3 colours plus "Other"). '
      'Got ${slices.length} — fold the tail into "Other", or use '
      'CategoryBreakdown for a long list.',
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _DonutPainter(
            slices: slices,
            surface: context.colors.surface,
            track: finance.chartTrack,
            thickness: thickness,
          ),
          child: const SizedBox.expand(),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (centerLabel != null)
              Text(
                centerLabel!,
                style: AppTypography.amountLarge.copyWith(
                  color: finance.textPrimary,
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
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.surface,
    required this.track,
    required this.thickness,
  });

  final List<ChartSlice> slices;
  final Color surface;
  final Color track;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      return;
    }

    // A 2px gap in the surface colour separates segments — the gap does the
    // separating, never a stroke drawn around each arc.
    final gapRadians = radius > 0 ? 2 / radius : 0.0;
    var start = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      final drawn = math.max(sweep - gapRadians, 0.0001);
      canvas.drawArc(
        rect,
        start + gapRadians / 2,
        drawn,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.thickness != thickness;
}

// -------------------------------------------------------- category breakdown

/// Spending by category, as labelled horizontal bars.
///
/// **The preferred form for a category breakdown**, and the answer to the
/// donut's three-segment limit. One colour for every bar, with the category
/// name and amount as real text beside it — so it scales to a dozen
/// categories, stays readable for any colour vision, and never clips a label
/// inside a short bar.
///
/// [ratio] per row is supplied by the caller (share of the largest, or of the
/// total). This widget does not compute it.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({required this.rows, super.key});

  final List<CategoryBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;

    return Column(
      children: [
        for (final row in rows) ...[
          Semantics(
            label:
                '${row.category}: ${row.amount.semanticLabel}'
                '${row.caption == null ? '' : ', ${row.caption}'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      row.category,
                      style: AppTypography.bodySmall.copyWith(
                        color: finance.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.barHorizontal,
                      child: Stack(
                        children: [
                          Container(height: 14, color: finance.chartTrack),
                          FractionallySizedBox(
                            widthFactor: row.ratio.clamp(0.0, 1.0),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: row.color ?? finance.chartSeries.first,
                                borderRadius: AppRadius.barHorizontal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 84,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: MoneyText(
                        row.amount,
                        size: MoneySize.small,
                        colorBySign: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One row of a [CategoryBreakdown].
class CategoryBreakdownRow {
  const CategoryBreakdownRow({
    required this.category,
    required this.amount,
    required this.ratio,
    this.color,
    this.caption,
  });

  final String category;
  final Money amount;

  /// Bar length, 0..1, computed by the caller.
  final double ratio;

  /// Defaults to series slot 1 — one colour for every bar.
  final Color? color;

  final String? caption;
}
