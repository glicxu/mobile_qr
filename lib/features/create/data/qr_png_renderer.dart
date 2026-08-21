import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

import '../domain/qr_center_decoration.dart';
import '../domain/qr_matrix.dart';

final class RenderedQrPng {
  const RenderedQrPng({
    required this.bytes,
    required this.canvasSize,
    required this.modulePixelSize,
    required this.qrOrigin,
  });

  final Uint8List bytes;
  final int canvasSize;
  final int modulePixelSize;
  final int qrOrigin;
}

final class QrPngRenderer {
  const QrPngRenderer({this.quietZoneModules = 4});

  final int quietZoneModules;

  RenderedQrPng render(
    QrMatrix matrix, {
    int size = 1024,
    QrCenterDecoration? centerDecoration,
    double centerCoverage = 0.20,
  }) {
    final totalModules = matrix.moduleCount + quietZoneModules * 2;
    final modulePixelSize = size ~/ totalModules;
    if (modulePixelSize < 1) {
      throw ArgumentError.value(size, 'size', 'Canvas is too small.');
    }

    final occupiedPixels = totalModules * modulePixelSize;
    final outerMargin = (size - occupiedPixels) ~/ 2;
    final qrOrigin = outerMargin + quietZoneModules * modulePixelSize;
    final canvas = image_lib.Image(width: size, height: size, numChannels: 4);
    image_lib.fill(canvas, color: image_lib.ColorRgba8(255, 255, 255, 255));

    for (var row = 0; row < matrix.moduleCount; row++) {
      for (var column = 0; column < matrix.moduleCount; column++) {
        if (!matrix.isDark(row, column)) continue;
        final x = qrOrigin + column * modulePixelSize;
        final y = qrOrigin + row * modulePixelSize;
        image_lib.fillRect(
          canvas,
          x1: x,
          y1: y,
          x2: x + modulePixelSize - 1,
          y2: y + modulePixelSize - 1,
          color: image_lib.ColorRgba8(0, 0, 0, 255),
          alphaBlend: false,
        );
      }
    }

    if (centerDecoration != null) {
      _drawCenterDecoration(
        canvas,
        matrix,
        centerDecoration,
        qrOrigin: qrOrigin,
        modulePixelSize: modulePixelSize,
        coverage: centerCoverage,
      );
    }

    return RenderedQrPng(
      bytes: Uint8List.fromList(image_lib.encodePng(canvas, level: 6)),
      canvasSize: size,
      modulePixelSize: modulePixelSize,
      qrOrigin: qrOrigin,
    );
  }

  void _drawCenterDecoration(
    image_lib.Image canvas,
    QrMatrix matrix,
    QrCenterDecoration decoration, {
    required int qrOrigin,
    required int modulePixelSize,
    required double coverage,
  }) {
    if (coverage <= 0 || coverage > 0.30) {
      throw ArgumentError.value(coverage, 'coverage', 'Use 0-30 percent.');
    }
    var overlayModules = (matrix.moduleCount * coverage).floor();
    if (overlayModules.isEven) overlayModules--;
    if (overlayModules < 5) overlayModules = 5;
    (int, int)? startModule;
    while (overlayModules >= 5 && startModule == null) {
      startModule = _nearestSafeOverlayStart(matrix, overlayModules);
      if (startModule == null && overlayModules > 5) {
        overlayModules -= 2;
      } else {
        break;
      }
    }
    startModule ??= (
      (matrix.moduleCount - overlayModules) ~/ 2,
      (matrix.moduleCount - overlayModules) ~/ 2,
    );
    final startX = qrOrigin + startModule.$1 * modulePixelSize;
    final startY = qrOrigin + startModule.$2 * modulePixelSize;
    final extent = overlayModules * modulePixelSize;
    image_lib.fillRect(
      canvas,
      x1: startX,
      y1: startY,
      x2: startX + extent - 1,
      y2: startY + extent - 1,
      color: image_lib.ColorRgba8(255, 255, 255, 255),
      alphaBlend: false,
    );

    switch (decoration.mode) {
      case QrCenterDecorationMode.none:
        return;
      case QrCenterDecorationMode.daliIcon:
        final bytes = decoration.iconPngBytes;
        final icon = bytes == null ? null : image_lib.decodeImage(bytes);
        if (icon == null) throw ArgumentError('Invalid Dali icon PNG.');
        image_lib.compositeImage(
          canvas,
          icon,
          dstX: startX,
          dstY: startY,
          dstW: extent,
          dstH: extent,
          blend: image_lib.BlendMode.alpha,
        );
      case QrCenterDecorationMode.customImage:
        final bytes = decoration.iconPngBytes;
        final selectedImage = bytes == null
            ? null
            : image_lib.decodeImage(bytes);
        if (selectedImage == null) {
          throw ArgumentError('The selected emblem image could not be read.');
        }
        final inset = modulePixelSize;
        final imageExtent = extent - inset * 2;
        final cropped = image_lib.copyResizeCropSquare(
          selectedImage,
          size: imageExtent,
          interpolation: image_lib.Interpolation.cubic,
        );
        image_lib.compositeImage(
          canvas,
          cropped,
          dstX: startX + inset,
          dstY: startY + inset,
          blend: image_lib.BlendMode.alpha,
        );
      case QrCenterDecorationMode.verificationCode:
        final code = decoration.verificationCode?.replaceAll('-', '');
        if (code == null || code.length != 6) {
          throw ArgumentError('A six-character verification code is required.');
        }
        final badge = image_lib.Image(width: 192, height: 192, numChannels: 4);
        image_lib.fill(badge, color: image_lib.ColorRgba8(255, 255, 255, 255));
        final color = image_lib.ColorRgba8(0, 0, 0, 255);
        image_lib.drawString(
          badge,
          code.substring(0, 3),
          font: image_lib.arial48,
          y: 41,
          color: color,
        );
        image_lib.drawString(
          badge,
          code.substring(3),
          font: image_lib.arial48,
          y: 103,
          color: color,
        );
        image_lib.compositeImage(
          canvas,
          badge,
          dstX: startX,
          dstY: startY,
          dstW: extent,
          dstH: extent,
          blend: image_lib.BlendMode.direct,
        );
    }
  }

  (int, int)? _nearestSafeOverlayStart(QrMatrix matrix, int overlayModules) {
    final centered = (matrix.moduleCount - overlayModules) ~/ 2;
    final alignmentCenters = _alignmentPatternCenters(matrix.version);
    var bestX = centered;
    var bestY = centered;
    var bestDistance = 1 << 30;
    for (var y = 8; y <= matrix.moduleCount - overlayModules - 8; y++) {
      for (var x = 8; x <= matrix.moduleCount - overlayModules - 8; x++) {
        final overlapsAlignment = alignmentCenters.any(
          (row) => alignmentCenters.any(
            (column) =>
                x <= column + 2 &&
                x + overlayModules - 1 >= column - 2 &&
                y <= row + 2 &&
                y + overlayModules - 1 >= row - 2,
          ),
        );
        if (overlapsAlignment) continue;
        final dx = x - centered;
        final dy = y - centered;
        final distance = dx * dx + dy * dy;
        if (distance < bestDistance) {
          bestDistance = distance;
          bestX = x;
          bestY = y;
        }
      }
    }
    return bestDistance == 1 << 30 ? null : (bestX, bestY);
  }

  List<int> _alignmentPatternCenters(int version) {
    if (version == 1) return const [];
    final count = version ~/ 7 + 2;
    final step = version == 32
        ? 26
        : ((version * 4 + count * 2 + 1) ~/ (count * 2 - 2)) * 2;
    final last = version * 4 + 10;
    return [
      6,
      for (var index = count - 2; index >= 0; index--) last - index * step,
    ];
  }
}
