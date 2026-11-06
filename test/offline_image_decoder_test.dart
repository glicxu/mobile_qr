import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dali_qr/features/scan/data/offline_image_decoder.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const decoder = OfflineImageDecoder();
  final fixtures =
      (jsonDecode(
                File(
                  'test/fixtures/optional_formats/manifest.json',
                ).readAsStringSync(),
              )
              as Map)['fixtures']
          as List;
  for (final fixture in fixtures) {
    test(
      'offline decoder preserves ${fixture['id']} exactly for every source',
      () async {
        final bytes = File(
          'test/fixtures/optional_formats/${fixture['id']}.png',
        ).readAsBytesSync();
        for (final source in ScanSource.values) {
          final result = (await decoder.decodeBytes(
            bytes,
            source: source,
          )).single;
          expect(result.value, fixture['value']);
          expect(result.format.storageKey, fixture['format']);
          expect(result.source, source);
          expect(result.rawBytes, isNull);
        }
      },
    );
  }
  for (final rotation in [90, 180, 270]) {
    test(
      'small Aztec survives rotation $rotation and JPEG compression',
      () async {
        final source = img.decodePng(
          File(
            'test/fixtures/optional_formats/aztec_short.png',
          ).readAsBytesSync(),
        )!;
        final image = img.copyRotate(source, angle: rotation);
        final result = await decoder.decodeBytes(
          img.encodeJpg(image, quality: 85),
          source: ScanSource.gallery,
        );
        expect(result.single.value, '  KEEP-00123  ');
        expect(result.single.format, ScannedCodeFormat.aztec);
      },
    );
  }
  test('multiple new formats with identical values remain distinct', () async {
    final canvas = img.Image(width: 1400, height: 600);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    for (final (i, name) in [
      'dataMatrix_short',
      'pdf417_short',
      'aztec_short',
    ].indexed) {
      final code = img.decodePng(
        File('test/fixtures/optional_formats/$name.png').readAsBytesSync(),
      )!;
      img.compositeImage(
        canvas,
        code,
        dstX: i == 0
            ? 10
            : i == 1
            ? 330
            : 1000,
        dstY: 150,
      );
    }
    final result = await decoder.decodeBytes(
      img.encodePng(canvas),
      source: ScanSource.sharedImage,
    );
    expect(result.map((code) => code.format), [
      ScannedCodeFormat.dataMatrix,
      ScannedCodeFormat.pdf417,
      ScannedCodeFormat.aztec,
    ]);
    expect(result.every((code) => code.value == '  KEEP-00123  '), isTrue);
  });
  test(
    'blank, malformed, too-large and timed-out images return bounded outcomes',
    () async {
      final image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      expect(
        await decoder.decodeBytes(
          img.encodePng(image),
          source: ScanSource.gallery,
        ),
        isEmpty,
      );
      await expectLater(
        decoder.decodeBytes(
          Uint8List.fromList([1, 2, 3]),
          source: ScanSource.gallery,
        ),
        throwsA(isA<ImageDecodeException>()),
      );
      await expectLater(
        decoder.decodeBytes(
          Uint8List(OfflineImageDecoder.maxBytes + 1),
          source: ScanSource.gallery,
        ),
        throwsA(isA<ImageDecodeException>()),
      );
      await expectLater(
        const OfflineImageDecoder(
          timeout: Duration.zero,
        ).decodeBytes(img.encodePng(image), source: ScanSource.gallery),
        throwsA(isA<ImageDecodeException>()),
      );
    },
  );
}
