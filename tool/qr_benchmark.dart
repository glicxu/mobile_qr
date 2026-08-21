import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';

void main() {
  const encoder = DartQrEncoder();
  const renderer = QrPngRenderer();
  final cases = <String, String>{
    'short ASCII': 'https://example.com/',
    'Unicode': 'https://例え.テスト/資料/😀?q=雪#章',
    '2,000 bytes': _urlWithByteLength(2000),
  };

  for (final entry in cases.entries) {
    for (var i = 0; i < 5; i++) {
      renderer.render(encoder.encode(entry.value));
    }

    final timings = <int>[];
    var version = 0;
    var pngBytes = 0;
    for (var i = 0; i < 30; i++) {
      final stopwatch = Stopwatch()..start();
      final matrix = encoder.encode(entry.value);
      final png = renderer.render(matrix);
      stopwatch.stop();
      timings.add(stopwatch.elapsedMicroseconds);
      version = matrix.version;
      pngBytes = png.bytes.length;
    }
    timings.sort();
    final median = timings[timings.length ~/ 2] / 1000;
    final p95 = timings[(timings.length * 0.95).floor() - 1] / 1000;
    stdout.writeln(
      '${entry.key.padRight(12)} '
      'version=${version.toString().padLeft(2)} '
      'pngBytes=${pngBytes.toString().padLeft(7)} '
      'median=${median.toStringAsFixed(1).padLeft(6)}ms '
      'p95=${p95.toStringAsFixed(1).padLeft(6)}ms',
    );
  }
}

String _urlWithByteLength(int targetBytes) {
  const prefix = 'https://example.com/';
  return '$prefix${'a' * (targetBytes - utf8.encode(prefix).length)}';
}
