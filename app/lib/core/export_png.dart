import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

// Captures a RepaintBoundary widget as a high-DPI PNG and opens the platform share/download sheet.

abstract final class ReceiptPngExporter {
  static Future<Uint8List?> captureBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  static Future<bool> shareBoundaryAsPng({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async {
    final bytes = await captureBoundary(boundaryKey);
    if (bytes == null || bytes.isEmpty) return false;

    final safeName = fileName.endsWith('.png') ? fileName : '$fileName.png';
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: safeName,
    );

    await Share.shareXFiles(
      [file],
      text: shareText,
    );
    return true;
  }
}
