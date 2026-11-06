import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/create/application/barcode_generator.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = <Map<String, dynamic>>[];
  for (final folder in ['barcodes', 'optional_formats']) {
    fixtures.addAll(
      ((jsonDecode(
                    File(
                      'test/fixtures/$folder/manifest.json',
                    ).readAsStringSync(),
                  )
                  as Map)['fixtures']
              as List)
          .cast<Map<String, dynamic>>(),
    );
  }
  final output = Directory('.dart_tool/generated-barcode-qa')
    ..createSync(recursive: true);
  final observed = <Map<String, dynamic>>[];
  for (final f in fixtures) {
    final format = ScannedCodeFormat.fromStorageKey(
      (f['symbolFormat'] ?? f['format']) as String,
    );
    if (format == ScannedCodeFormat.qrCode) continue;
    test('generates ${f['id']} without changing its value', () async {
      final value = (f['encodedValue'] ?? f['value']) as String;
      final code = await BarcodeGenerator.generate(value, format);
      expect(code.value, value);
      expect(code.format, format);
      final png = img.decodePng(code.png)!;
      expect(png.width, code.width);
      expect(png.height, code.height);
      expect(png.getPixel(0, 0).r, 255);
      expect(code.width, lessThanOrEqualTo(4096));
      final name = '${f['id']}.png';
      File('${output.path}/$name').writeAsBytesSync(code.png);
      observed.add({
        'id': f['id'],
        'format': format.storageKey,
        'value': value,
        'file': name,
      });
    });
  }
  for (final format in [
    ScannedCodeFormat.dataMatrix,
    ScannedCodeFormat.pdf417,
    ScannedCodeFormat.aztec,
  ]) {
    test('${format.name} preserves Unicode and whitespace', () async {
      final value = format == ScannedCodeFormat.dataMatrix
          ? '  Café Grüße\nend  '
          : '  Café 中文 😀\nend  ';
      final code = await BarcodeGenerator.generate(value, format);
      final name = '${format.name}_text.png';
      File('${output.path}/$name').writeAsBytesSync(code.png);
      observed.add({
        'id': '${format.name}_unicode',
        'format': format.storageKey,
        'value': value,
        'file': name,
      });
    });
  }
  tearDownAll(
    () => File(
      '${output.path}/manifest.json',
    ).writeAsStringSync(jsonEncode({'fixtures': observed})),
  );

  test(
    'rejects incorrect identifier lengths, check digits and UPC-E structure',
    () {
      for (final entry in {
        ScannedCodeFormat.upcA: [
          '01234567890',
          '012345678906',
          ' 012345678905',
        ],
        ScannedCodeFormat.ean8: ['1234567', '12345671'],
        ScannedCodeFormat.ean13: ['978030640615', '9780306406158'],
        ScannedCodeFormat.itf14: ['0001234567890', '00012345678906'],
        ScannedCodeFormat.upcE: ['0425261', '04252615', '24252614', '01200041'],
      }.entries) {
        for (final value in entry.value) {
          expect(
            () => BarcodeGenerator.validate(value, entry.key),
            throwsFormatException,
            reason: '${entry.key}: $value',
          );
        }
      }
    },
  );
  test(
    'rejects unsupported characters, content bounds and unknown formats',
    () {
      for (final format in [
        ScannedCodeFormat.code39,
        ScannedCodeFormat.code93,
      ]) {
        expect(
          () => BarcodeGenerator.validate('lowercase', format),
          throwsFormatException,
        );
        expect(
          () => BarcodeGenerator.validate('*START*', format),
          throwsFormatException,
        );
      }
      expect(
        () => BarcodeGenerator.validate('中文', ScannedCodeFormat.code128),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('1234', ScannedCodeFormat.codabar),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('AABCDA', ScannedCodeFormat.codabar),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('x' * 81, ScannedCodeFormat.code128),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('x' * 1201, ScannedCodeFormat.aztec),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('', ScannedCodeFormat.aztec),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('😀', ScannedCodeFormat.dataMatrix),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate('x', ScannedCodeFormat.unknown),
        throwsFormatException,
      );
      expect(
        () => BarcodeGenerator.validate(
          String.fromCharCode(0xd800),
          ScannedCodeFormat.pdf417,
        ),
        throwsFormatException,
      );
    },
  );
}
