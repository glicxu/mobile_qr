import 'dart:io';

import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';
import 'package:dali_qr/features/create/domain/qr_center_decoration.dart';
import 'package:image/image.dart' as image;

void main() {
  const payload = 'https://example.com/products/123';
  const encoder = DartQrEncoder();
  const renderer = QrPngRenderer();
  final matrix = encoder.encode(
    payload,
    strength: QrEncodingStrength.decorated,
  );
  final output = Directory('build/center-decoration-spike')
    ..createSync(recursive: true);

  final code = renderer.render(
    matrix,
    centerDecoration: const QrCenterDecoration.verificationCode('ABC-923'),
  );
  File('${output.path}/verification-code.png').writeAsBytesSync(code.bytes);

  final icon = File('assets/dali_smart_code_icon.png').readAsBytesSync();
  final branded = renderer.render(
    matrix,
    centerDecoration: QrCenterDecoration.daliIcon(icon),
  );
  File('${output.path}/dali-icon.png').writeAsBytesSync(branded.bytes);

  for (final rendered in [code, branded]) {
    final decoded = image.decodePng(rendered.bytes)!;
    final corner = decoded.getPixel(0, 0);
    stdout.writeln(
      '${decoded.width}x${decoded.height} corner='
      '${corner.r},${corner.g},${corner.b},${corner.a}',
    );
  }
}
