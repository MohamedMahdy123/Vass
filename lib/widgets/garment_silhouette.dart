import 'package:flutter/material.dart';

/// A clean flat-lay garment silhouette, drawn in the item's own colour and
/// centred on a transparent ground so it reads like an isolated catalog
/// product shot. Used as the fallback whenever a piece has no background-removed
/// cut-out photo (demo/seed pieces, manual adds, pre-processing state).
///
/// The shape is chosen from the garment's [category]; unknown categories fall
/// back to a neatly folded garment.
class GarmentSilhouette extends StatelessWidget {
  const GarmentSilhouette({
    super.key,
    required this.category,
    required this.color,
    this.inset = 0.16,
  });

  final String? category;
  final Color color;

  /// Fraction of the box kept as breathing room around the shape (0–0.4), so
  /// the garment is centred without touching the card edges.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GarmentPainter(category, color, inset),
    );
  }
}

class _GarmentPainter extends CustomPainter {
  _GarmentPainter(this.category, this.color, this.inset);

  final String? category;
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;

    // Work in a 100×100 space, then map into the centred, inset square.
    final pad = side * inset.clamp(0.0, 0.4);
    final draw = side - pad * 2;
    final dx = (size.width - draw) / 2;
    final dy = (size.height - draw) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(draw / 100);

    final path = _pathFor(category);

    // Soft contact shadow beneath the garment.
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Base fill.
    canvas.drawPath(path, Paint()..color = color);

    // Gentle top-down sheen so the flat colour reads as fabric.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.16), Colors.black.withOpacity(0.10)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );

    // Crisp seam outline.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withOpacity(0.16),
    );

    canvas.restore();
  }

  Path _pathFor(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'bottoms':
        return _bottoms();
      case 'outerwear':
        return _outerwear();
      case 'footwear':
        return _footwear();
      case 'dresses':
        return _dress();
      case 'accessories':
        return _accessory();
      case 'tops':
        return _top();
      default:
        return _folded();
    }
  }

  // ---- shapes (100×100 space) --------------------------------------------

  Path _top() {
    final p = Path()
      ..moveTo(34, 20)
      ..lineTo(14, 34)
      ..lineTo(24, 50)
      ..lineTo(34, 44)
      ..lineTo(34, 86)
      ..lineTo(66, 86)
      ..lineTo(66, 44)
      ..lineTo(76, 50)
      ..lineTo(86, 34)
      ..lineTo(66, 20)
      // neckline dip back to the left shoulder
      ..quadraticBezierTo(58, 30, 50, 30)
      ..quadraticBezierTo(42, 30, 34, 20)
      ..close();
    return p;
  }

  Path _outerwear() {
    final p = Path()
      ..moveTo(34, 18)
      ..lineTo(12, 32)
      ..lineTo(22, 52)
      ..lineTo(33, 46)
      ..lineTo(33, 90)
      ..lineTo(67, 90)
      ..lineTo(67, 46)
      ..lineTo(78, 52)
      ..lineTo(88, 32)
      ..lineTo(66, 18)
      // lapels meeting at centre
      ..lineTo(54, 30)
      ..lineTo(50, 44)
      ..lineTo(46, 30)
      ..close();
    return p;
  }

  Path _bottoms() {
    final p = Path()
      ..moveTo(32, 14)
      ..lineTo(68, 14)
      ..lineTo(66, 52)
      ..lineTo(62, 88)
      ..lineTo(52, 88)
      ..lineTo(50, 50) // inseam crotch point
      ..lineTo(48, 88)
      ..lineTo(38, 88)
      ..lineTo(34, 52)
      ..close();
    return p;
  }

  Path _footwear() {
    // A low shoe profile.
    final p = Path()
      ..moveTo(16, 64)
      ..quadraticBezierTo(16, 46, 40, 44)
      ..lineTo(52, 44)
      ..quadraticBezierTo(84, 46, 86, 66)
      ..lineTo(86, 72)
      ..lineTo(18, 72)
      ..quadraticBezierTo(16, 70, 16, 64)
      ..close();
    return p;
  }

  Path _dress() {
    final p = Path()
      ..moveTo(38, 18)
      ..lineTo(22, 30)
      ..lineTo(30, 42)
      ..lineTo(38, 38)
      ..lineTo(30, 88) // flared hem left
      ..lineTo(70, 88)
      ..lineTo(62, 38)
      ..lineTo(70, 42)
      ..lineTo(78, 30)
      ..lineTo(62, 18)
      ..quadraticBezierTo(50, 28, 38, 18)
      ..close();
    return p;
  }

  Path _accessory() {
    // A folded scarf / rectangular accessory.
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 30, 48, 40),
        const Radius.circular(8),
      ));
    return p;
  }

  Path _folded() {
    // A neatly folded garment: rounded square with a fold seam.
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 26, 52, 48),
        const Radius.circular(10),
      ));
    return p;
  }

  @override
  bool shouldRepaint(_GarmentPainter old) =>
      old.color != color || old.category != category || old.inset != inset;
}
