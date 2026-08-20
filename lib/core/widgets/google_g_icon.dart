import 'package:flutter/material.dart';

/// The official Google "G" mark, drawn with four brand-colored arcs.
///
/// Sized to a fixed 18×18 box so it sits nicely alongside the "Continue
/// with Google" label in a button. Using [CustomPaint] avoids shipping a
/// separate PNG asset for a single character.
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGIconPainter(),
      ),
    );
  }
}

class _GoogleGIconPainter extends CustomPainter {
  // Official Google brand colors (https://developers.google.com/identity/branding-guidelines).
  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double radius = w / 2;
    final Offset center = Offset(w / 2, h / 2);
    final Rect bounds = Rect.fromCircle(center: center, radius: radius);

    final Paint blue = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32
      ..strokeCap = StrokeCap.butt;

    final Paint red = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32
      ..strokeCap = StrokeCap.butt;

    final Paint yellow = Paint()
      ..color = _yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32
      ..strokeCap = StrokeCap.butt;

    final Paint green = Paint()
      ..color = _green
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32
      ..strokeCap = StrokeCap.butt;

    // Circle is split into 4 arcs starting at the top (12 o'clock), going
    // clockwise: blue top → red right → yellow bottom → green left.
    canvas.drawArc(bounds, -1.5708, 1.5708, false, blue);   // top
    canvas.drawArc(bounds, 0.0, 1.5708, false, red);         // right
    canvas.drawArc(bounds, 1.5708, 1.5708, false, yellow);   // bottom
    canvas.drawArc(bounds, 3.1416, 1.5708, false, green);    // left

    // The horizontal "tongue" of the G — the small line that points right
    // from the center on the right side.
    final double stroke = radius * 0.32;
    final Paint tongue = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.85, center.dy),
      tongue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGIconPainter oldDelegate) => false;
}
