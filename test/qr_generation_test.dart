import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dali_qr/features/create/application/qr_encoder.dart';
import 'package:dali_qr/features/create/application/qr_png_validator.dart';
import 'package:dali_qr/features/create/data/dart_qr_encoder.dart';
import 'package:dali_qr/features/create/data/qr_png_renderer.dart';
import 'package:dali_qr/features/create/domain/qr_center_decoration.dart';
import 'package:dali_qr/features/create/domain/url_payload_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:zxing2/qrcode.dart';

import 'fixtures/url_fixtures.dart';

void main() {
  const policy = UrlPayloadPolicy();
  const encoder = DartQrEncoder();
  const renderer = QrPngRenderer();
  const validator = QrPngValidator();

  group('QR generation', () {
    for (final fixture in acceptedUrlFixtures) {
      test('ZXing exactly decodes ${fixture.name}', () {
        final payload = policy.validate(fixture.input);
        final matrix = encoder.encode(payload.value);
        final png = renderer.render(matrix);

        expect(matrix.moduleCount, matrix.version * 4 + 17);
        expect(
          matrix.modules,
          hasLength(matrix.moduleCount * matrix.moduleCount),
        );
        expect(png.modulePixelSize, greaterThan(0));
        expect(decodeQrPng(png.bytes), payload.value);
      });
    }

    test('round trips the 2,000-byte product ceiling', () {
      const prefix = 'https://example.com/';
      final input = '$prefix${'a' * (2000 - prefix.length)}';
      final payload = policy.validate(input);
      final matrix = encoder.encode(payload.value);
      final png = renderer.render(matrix);

      expect(matrix.version, lessThanOrEqualTo(40));
      expect(decodeQrPng(png.bytes), input);
    });

    test('selects larger versions as payload size grows', () {
      final short = encoder.encode('https://example.com/');
      final long = encoder.encode('https://example.com/${'a' * 500}');
      expect(long.version, greaterThan(short.version));
    });

    test('PNG uses an opaque white background and four-module quiet zone', () {
      final matrix = encoder.encode('https://example.com/');
      final rendered = renderer.render(matrix);
      final decodedImage = image_lib.decodePng(rendered.bytes)!;
      final requiredQuietPixels = rendered.modulePixelSize * 4;
      final firstDarkPixel = rendered.qrOrigin;

      expect(firstDarkPixel, greaterThanOrEqualTo(requiredQuietPixels));
      final corner = decodedImage.getPixel(0, 0);
      expect((corner.r, corner.g, corner.b, corner.a), (255, 255, 255, 255));
    });

    test('verification badge decodes at spike coverage candidates', () {
      const input = 'https://example.com/products/123?campaign=summer';
      final matrix = encoder.encode(
        input,
        strength: QrEncodingStrength.decorated,
      );
      for (final coverage in const [0.15, 0.20, 0.25]) {
        final png = renderer.render(
          matrix,
          centerCoverage: coverage,
          centerDecoration: const QrCenterDecoration.verificationCode(
            'ABC-923',
          ),
        );
        expect(
          decodeQrPng(png.bytes),
          input,
          reason: 'Verification badge failed at ${coverage * 100} percent.',
        );
      }
    });

    test('verification badge uses only OCR-friendly grayscale colors', () {
      final matrix = encoder.encode(
        'https://example.com/',
        strength: QrEncodingStrength.decorated,
      );
      final png = renderer.render(
        matrix,
        centerDecoration: const QrCenterDecoration.verificationCode('ABC-923'),
      );
      final decoded = image_lib.decodePng(png.bytes)!;

      expect(
        decoded.every(
          (pixel) => pixel.r == pixel.g && pixel.g == pixel.b && pixel.a == 255,
        ),
        isTrue,
      );
    });

    test('Dali icon decodes across representative payload sizes', () {
      final icon = File('assets/dali_smart_code_icon.png').readAsBytesSync();
      for (final length in const [20, 100, 500, 1000]) {
        final input = 'https://example.com/${'a' * length}';
        final matrix = encoder.encode(
          input,
          strength: QrEncodingStrength.decorated,
        );
        final usePureExtraction = length >= 500;
        expect(
          decodeQrPng(renderer.render(matrix).bytes, pure: usePureExtraction),
          input,
          reason: 'Level H baseline failed at version ${matrix.version}.',
        );
        final png = renderer.render(
          matrix,
          centerDecoration: QrCenterDecoration.daliIcon(icon),
        );
        try {
          expect(
            decodeQrPng(png.bytes, pure: usePureExtraction),
            input,
            reason: 'Dali icon failed with a $length-character path.',
          );
        } on Object catch (error) {
          fail(
            'Dali icon failed with a $length-character path '
            '(version ${matrix.version}, ${matrix.moduleCount} modules): '
            '$error',
          );
        }
      }
    });

    test('Dali icon decodes at spike coverage candidates', () {
      const input = 'https://example.com/products/123?campaign=summer';
      final icon = File('assets/dali_smart_code_icon.png').readAsBytesSync();
      final matrix = encoder.encode(
        input,
        strength: QrEncodingStrength.decorated,
      );
      for (final coverage in const [0.15, 0.20, 0.25]) {
        final png = renderer.render(
          matrix,
          centerCoverage: coverage,
          centerDecoration: QrCenterDecoration.daliIcon(icon),
        );
        expect(
          decodeQrPng(png.bytes),
          input,
          reason: 'Dali icon failed at ${coverage * 100} percent.',
        );
      }
    });

    test('custom center image is cropped and runtime validated', () {
      const input = 'A custom message inside a Dali Secure QR';
      final image = File('assets/dali_smart_code_icon.png').readAsBytesSync();
      final matrix = encoder.encode(
        input,
        strength: QrEncodingStrength.decorated,
      );
      final png = renderer.render(
        matrix,
        centerDecoration: QrCenterDecoration.customImage(image),
      );

      expect(validator.containsExactPayload(png.bytes, input), isTrue);
      expect(
        validator.containsExactPayload(png.bytes, '$input changed'),
        isFalse,
      );
    });

    test('verification badge decodes across representative payload sizes', () {
      for (final length in const [20, 100, 500, 1000]) {
        final input = 'https://example.com/${'b' * length}';
        final matrix = encoder.encode(
          input,
          strength: QrEncodingStrength.decorated,
        );
        final png = renderer.render(
          matrix,
          centerDecoration: const QrCenterDecoration.verificationCode(
            'ABC-923',
          ),
        );
        expect(
          decodeQrPng(png.bytes, pure: length >= 500),
          input,
          reason: 'Badge failed at version ${matrix.version}.',
        );
      }
    });

    test('Level H rejects content above its maximum capacity', () {
      expect(
        () =>
            encoder.encode('a' * 2000, strength: QrEncodingStrength.decorated),
        throwsA(isA<QrPayloadTooLongException>()),
      );
    });
  });
}

String decodeQrPng(Uint8List pngBytes, {bool pure = false}) {
  final decodedImage = image_lib.decodePng(pngBytes)!;
  final rgba = decodedImage
      .convert(numChannels: 4)
      .getBytes(order: image_lib.ChannelOrder.rgba);
  final source = RGBLuminanceSource(
    decodedImage.width,
    decodedImage.height,
    rgba.buffer.asInt32List(rgba.offsetInBytes, rgba.lengthInBytes ~/ 4),
  );
  final hints = DecodeHints();
  if (pure) hints.put(DecodeHintType.pureBarcode);
  final result = QRCodeReader().decode(
    BinaryBitmap(HybridBinarizer(source)),
    hints: hints,
  );
  if (!result.text.contains('\u{fffd}')) return result.text;

  // zxing2 0.2.4 stores decoded bytes in an Int8List and passes its negative
  // values directly to Dart's UTF-8 decoder. That port-specific signed-byte
  // bug produces replacement characters even though ZXing has read the ECI
  // segment and recovered the correct bytes. Reconstruct the unsigned byte
  // segment so this test still verifies the independently decoded QR data.
  final byteSegments =
      result.resultMetadata[ResultMetadataType.byteSegments] as List<Int8List>?;
  if (byteSegments == null) return result.text;
  return byteSegments
      .map(
        (segment) => utf8.decode(segment.map((byte) => byte & 0xff).toList()),
      )
      .join();
}
