import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The Google "G", drawn rather than shipped as an image.
///
/// A painter avoids adding a binary asset and the pubspec entry, resolution
/// variants and licence bookkeeping that come with one, and it stays crisp at
/// any size. The mark is four arcs and a bar, which is little enough geometry
/// to be worth drawing directly.
///
/// The colours are Google's published brand values and are intentionally the
/// one place in this feature that does not use design system tokens: they
/// identify a third party, so they must not shift when our palette does.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _GoogleLogoPainter(),
      // The mark carries the meaning already stated by the button's label,
      // so announcing it again would make a screen reader say "Google"
      // twice.
      isComplex: false,
    ),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.26;
    final radius = (size.width - stroke) / 2;
    final centre = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles run clockwise from 3 o'clock, matching the canvas convention.
    // The gap between the blue arc's end and the green arc's start is where
    // the crossbar enters.
    void arc(Color color, double startDegrees, double sweepDegrees) {
      canvas.drawArc(
        rect,
        _rad(startDegrees),
        _rad(sweepDegrees),
        false,
        paint..color = color,
      );
    }

    arc(_red, 232, 72); // top
    arc(_blue, 304, 73); // upper right, down to the bar
    arc(_green, 50, 100); // bottom
    arc(_yellow, 150, 82); // left

    // The crossbar: from the centre out to the right edge, level with the
    // middle, closing the G.
    canvas.drawRect(
      Rect.fromLTRB(
        centre.dx,
        centre.dy - stroke / 2,
        centre.dx + radius + stroke / 2,
        centre.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
