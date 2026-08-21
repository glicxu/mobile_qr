import 'dart:io';

import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';

void main() {
  const encoder = DartQrEncoder();
  const renderer = QrPngRenderer();
  final output = Directory('build/qr_fixtures')..createSync(recursive: true);
  const fixtures = <String, String>{
    'ascii': 'https://example.com/a%2fb?q=one+two#result',
    'unicode': 'https://例え.テスト/資料/😀?q=雪#章',
  };

  for (final entry in fixtures.entries) {
    final rendered = renderer.render(encoder.encode(entry.value));
    File('${output.path}/${entry.key}.png').writeAsBytesSync(rendered.bytes);
    File('${output.path}/${entry.key}.txt').writeAsStringSync(entry.value);
  }
}
