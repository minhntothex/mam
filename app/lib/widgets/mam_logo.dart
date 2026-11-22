import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Vector brand mark for Mâm: a round shared dining tray ("mâm") with one
/// cleanly detached mint-emerald fair-share wedge inside a Canon fintech blue
/// squircle.
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
      final tileRect = const Rect.fromLTWH(0, 0, _designSize, _designSize);
      final tilePaint = Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A74FF), Color(0xFF004CE6)],
        ).createShader(tileRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tileRect, const Radius.circular(224)),
        tilePaint,
      );
    }

    // Main shared tray ring (252° sweep, centered at 496, 528).
    final trayPath = _annularSector(
      center: const Offset(496, 528),
      rOuter: 304,
      rInner: 134,
      startDeg: 9,
      sweepDeg: 252,
    );
    final trayPaint = Paint()
      ..isAntiAlias = true
      ..color = showTile ? Colors.white : const Color(0xFF0066FF);
    canvas.drawPath(trayPath, trayPaint);

    // Detached fair-share wedge (76° sweep, offset +44 / -44 at 540, 484).
    final sharePath = _annularSector(
      center: const Offset(540, 484),
      rOuter: 304,
      rInner: 134,
      startDeg: 277,
      sweepDeg: 76,
    );
    final sharePaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5EEAD4), Color(0xFF10B981)],
      ).createShader(sharePath.getBounds());
    canvas.drawPath(sharePath, sharePaint);

    canvas.restore();
  }

  static Path _annularSector({
    required Offset center,
    required double rOuter,
    required double rInner,
    required double startDeg,
    required double sweepDeg,
  }) {
    final startRad = startDeg * _degToRad;
    final sweepRad = sweepDeg * _degToRad;
    return Path()
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
  }

  @override
  bool shouldRepaint(covariant _MamLogoPainter oldDelegate) =>
      oldDelegate.showTile != showTile;
}
