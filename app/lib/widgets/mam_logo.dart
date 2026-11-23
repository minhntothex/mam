import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Vector brand mark for Mâm (Tri-Pastel Share): three rich pastel slices —
/// sky periwinkle, fresh mint, and a detached honey-butter fair-share wedge —
/// arranged as a shared round dining tray ("mâm") inside a clean flat
/// borderless cloud-white tile.
///
/// Mirrors `assets/brand/mam-logo.svg` in a normalized 1024×1024 coordinate
/// space so the AppBar mark, exported PNG Receipt Cards, and platform icons
/// share identical geometry.
class MamLogoMark extends StatelessWidget {
  const MamLogoMark({
    super.key,
    this.size = 32,
    this.showTile = true,
  });

  final double size;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MamLogoPainter(showTile: showTile),
      ),
    );
  }
}

class _MamLogoPainter extends CustomPainter {
  const _MamLogoPainter({required this.showTile});

  final bool showTile;

  static const double _designSize = 1024.0;
  static const double _degToRad = math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _designSize;
    canvas.save();
    canvas.scale(scale);

    if (showTile) {
      const tileRect = Rect.fromLTWH(0, 0, 1024, 1024);
      final tileRRect = RRect.fromRectAndRadius(
        tileRect,
        const Radius.circular(220),
      );
      final tilePaint = Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF1FF)],
        ).createShader(tileRect);
      canvas.drawRRect(tileRRect, tilePaint);
    }

    // Bottom-left Sky Periwinkle slice (15° -> 165°).
    _drawGradientSlice(
      canvas,
      center: const Offset(502, 522),
      rOuter: 304,
      rInner: 134,
      startDeg: 15,
      sweepDeg: 150,
      colors: const [Color(0xFF72ADFF), Color(0xFF3E7EF5)],
    );

    // Top-left Mint slice (177° -> 267°).
    _drawGradientSlice(
      canvas,
      center: const Offset(502, 522),
      rOuter: 304,
      rInner: 134,
      startDeg: 177,
      sweepDeg: 90,
      colors: const [Color(0xFF69E3B6), Color(0xFF2AC28B)],
    );

    // Detached top-right Honey-Butter fair-share wedge (281° -> 359°).
    _drawGradientSlice(
      canvas,
      center: const Offset(544, 480),
      rOuter: 304,
      rInner: 134,
      startDeg: 281,
      sweepDeg: 78,
      colors: const [Color(0xFFFFD66B), Color(0xFFF79E38)],
    );

    canvas.restore();
  }

  static void _drawGradientSlice(
    Canvas canvas, {
    required Offset center,
    required double rOuter,
    required double rInner,
    required double startDeg,
    required double sweepDeg,
    required List<Color> colors,
  }) {
    final startRad = startDeg * _degToRad;
    final sweepRad = sweepDeg * _degToRad;
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: rOuter),
        startRad,
        sweepRad,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: rInner),
        startRad + sweepRad,
        -sweepRad,
        false,
      )
      ..close();

    final paint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(path.getBounds());
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MamLogoPainter oldDelegate) =>
      oldDelegate.showTile != showTile;
}
