import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/qr_matrix.dart';

final class QrMatrixPainter extends CustomPainter {
  const QrMatrixPainter(this.matrix, {this.quietZoneModules = 4});

  final QrMatrix matrix;
  final int quietZoneModules;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final totalModules = matrix.moduleCount + quietZoneModules * 2;
    final dimension = math.min(size.width, size.height);
    final moduleSize = dimension / totalModules;
    final left = (size.width - dimension) / 2 + quietZoneModules * moduleSize;
    final top = (size.height - dimension) / 2 + quietZoneModules * moduleSize;
    final darkPaint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;

    for (var row = 0; row < matrix.moduleCount; row++) {
      for (var column = 0; column < matrix.moduleCount; column++) {
        if (!matrix.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + column * moduleSize,
            top + row * moduleSize,
            moduleSize,
            moduleSize,
          ),
          darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrMatrixPainter oldDelegate) =>
      !identical(matrix, oldDelegate.matrix);
}
