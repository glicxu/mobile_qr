import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/lookup/domain/identifier_recognizer.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const recognizer = IdentifierRecognizer();
  IdentifierRecognition? inspect(String value, ScannedCodeFormat format) =>
      recognizer.recognize(value: value, format: format);

  test('retail formats retain their exact value and format', () {
    const cases = [
      ('012345678905', ScannedCodeFormat.upcA, IdentifierKind.upcA),
      ('96385074', ScannedCodeFormat.ean8, IdentifierKind.ean8),
      ('5012345678900', ScannedCodeFormat.ean13, IdentifierKind.ean13),
      ('9780306406157', ScannedCodeFormat.ean13, IdentifierKind.isbn13),
    ];
    for (final (value, format, kind) in cases) {
      final result = inspect(value, format)!;
      expect(result.originalValue, value);
      expect(result.originalFormat, format);
      expect(result.kind, kind);
      expect(result.validation, IdentifierValidation.checkDigitMatches);
      expect(result.normalizedValue, value);
      expect(result.derivedLookupValue, value);
      expect(result.normalizationNote, isNull);
    }
  });

  test('native UPC-A and zero-prefixed EAN-13 remain distinct', () {
    final upca = inspect('012345678905', ScannedCodeFormat.upcA)!;
    final ean = inspect('0012345678905', ScannedCodeFormat.ean13)!;
    expect(upca.derivedLookupValue, '012345678905');
    expect(ean.derivedLookupValue, '0012345678905');
    expect(ean.kind, IdentifierKind.ean13);
  });

  test('UPC-E expands all rule branches without replacing the scan', () {
    // First four vectors: GS1 General Specifications 24.0, figures 5.2.2.4.1-2..5.
    const vectors = {
      '01234558': '012345000058',
      '04567840': '045670000080',
      '03456703': '034000005673',
      '09847531': '098400000751',
      // Independent barcode fixtures and a synthetic selector-2 example.
      '04252614': '042100005264',
      '04252623': '042200005263',
      '01234565': '012345000065',
    };
    for (final entry in vectors.entries) {
      final result = inspect(entry.key, ScannedCodeFormat.upcE)!;
      expect(
        result.validation,
        IdentifierValidation.checkDigitMatches,
        reason: entry.key,
      );
      expect(result.originalValue, entry.key);
      expect(result.normalizedValue, entry.key);
      expect(result.derivedLookupValue, entry.value);
      expect(result.normalizationNote, contains('scan is unchanged'));
    }
  });

  test('UPC-E never guesses missing digits or nonstandard number systems', () {
    for (final value in ['425261', '0425261', '042526140']) {
      final result = inspect(value, ScannedCodeFormat.upcE)!;
      expect(result.validation, IdentifierValidation.invalidStructure);
      expect(result.derivedLookupValue, isNull);
    }
    expect(
      inspect('11234562', ScannedCodeFormat.upcE)!.validation,
      IdentifierValidation.unsupported,
    );
    for (final value in [
      '01204530',
      '01230540',
      '01234050',
      '01234060',
      '01234070',
      '01234080',
      '01234090',
    ]) {
      final result = inspect(value, ScannedCodeFormat.upcE)!;
      expect(
        result.validation,
        IdentifierValidation.invalidStructure,
        reason: value,
      );
      expect(result.derivedLookupValue, isNull);
    }
  });

  test('bad check digits are explained without autocorrection', () {
    for (final (value, format) in [
      ('012345678906', ScannedCodeFormat.upcA),
      ('04252615', ScannedCodeFormat.upcE),
      ('96385075', ScannedCodeFormat.ean8),
      ('5012345678901', ScannedCodeFormat.ean13),
      ('9780306406158', ScannedCodeFormat.ean13),
      ('ISBN: 0306406153', ScannedCodeFormat.qrCode),
    ]) {
      final result = inspect(value, format)!;
      expect(
        result.validation,
        IdentifierValidation.invalidCheckDigit,
        reason: value,
      );
      expect(result.originalValue, value);
      expect(result.derivedLookupValue, isNull);
    }
  });

  test('explicit ISBN-10 labels support X and separately derive ISBN-13', () {
    final result = inspect('ISBN-10: 0-8044-2957-x', ScannedCodeFormat.qrCode)!;
    expect(result.kind, IdentifierKind.isbn10);
    expect(result.validation, IdentifierValidation.checkDigitMatches);
    expect(result.originalValue, 'ISBN-10: 0-8044-2957-x');
    expect(result.normalizedValue, '080442957X');
    expect(result.derivedLookupValue, '9780804429573');
    expect(result.normalizationNote, contains('Uppercased'));
    expect(result.normalizationNote, contains('Converted ISBN-10'));
    expect(
      inspect('isbn 0306406152', ScannedCodeFormat.code128)!.derivedLookupValue,
      '9780306406157',
    );
  });

  test('ISBN-13 prefixes are candidates, not allocation or catalog claims', () {
    for (final value in [
      '9780306406157',
      '9791234567896',
      '978-0-306-40615-7',
    ]) {
      final result = inspect(value, ScannedCodeFormat.code128)!;
      expect(result.kind, IdentifierKind.isbn13);
      expect(result.validation, IdentifierValidation.checkDigitMatches);
      expect(result.derivedLookupValue!.length, 13);
    }
    final music = inspect('9790123456785', ScannedCodeFormat.ean13)!;
    expect(music.kind, IdentifierKind.ean13);
    expect(music.validation, IdentifierValidation.checkDigitMatches);
    expect(inspect('9790123456785', ScannedCodeFormat.qrCode), isNull);
    expect(
      inspect('ISBN-13: 9790123456785', ScannedCodeFormat.qrCode)!.validation,
      IdentifierValidation.invalidStructure,
    );
    expect(
      inspect('5012345678900', ScannedCodeFormat.ean13)!.kind,
      IdentifierKind.ean13,
    );
  });

  test('arbitrary numeric text and bare ISBN-10 remain unclassified', () {
    for (final value in [
      '012345678905',
      '96385074',
      '5012345678900',
      '0306406152',
      '080442957X',
      '1234567890',
      'ISBN: not an identifier',
      'https://example.com/9780306406157',
      'FIDO:/9780306406157',
    ]) {
      expect(inspect(value, ScannedCodeFormat.qrCode), isNull, reason: value);
    }
    expect(inspect('10012345000017', ScannedCodeFormat.itf14), isNull);
  });

  test(
    'retail validation accepts only exact ASCII shape and preserves raw data',
    () {
      for (final value in [
        ' 012345678905',
        '012345678905 ',
        '012345678905\n',
        '01234567890X',
        '０１２３４５６７８９０５',
        '+012345678905',
        '01234-678905',
      ]) {
        final result = inspect(value, ScannedCodeFormat.upcA)!;
        expect(result.validation, IdentifierValidation.invalidStructure);
        expect(result.originalValue, value);
        expect(result.normalizedValue, isNull);
        expect(result.derivedLookupValue, isNull);
      }
    },
  );

  test('declared ISBN type must match its shape and supported prefix', () {
    for (final value in [
      'ISBN-10: 9780306406157',
      'ISBN-13: 0306406152',
      'ISBN: 5012345678900',
      'ISBN-10: X804429570',
      'ISBN-13: 978030640615X',
    ]) {
      final result = inspect(value, ScannedCodeFormat.code128)!;
      expect(
        result.validation,
        IdentifierValidation.invalidStructure,
        reason: value,
      );
      expect(result.derivedLookupValue, isNull);
    }
    expect(
      inspect('ISBN: 9780306406157\nextra', ScannedCodeFormat.qrCode),
      isNull,
    );
    expect(inspect('ISBN: ${'9' * 200}', ScannedCodeFormat.qrCode), isNull);
  });

  test(
    'single-digit corruption of GTIN values is detected at every position',
    () {
      for (final (original, format) in [
        ('012345678905', ScannedCodeFormat.upcA),
        ('96385074', ScannedCodeFormat.ean8),
        ('5012345678900', ScannedCodeFormat.ean13),
      ]) {
        for (var index = 0; index < original.length; index++) {
          final value = original.replaceRange(
            index,
            index + 1,
            ((int.parse(original[index]) + 1) % 10).toString(),
          );
          final result = inspect(value, format)!;
          expect(
            result.validation,
            IdentifierValidation.invalidCheckDigit,
            reason: value,
          );
          expect(result.derivedLookupValue, isNull);
        }
      }
    },
  );

  test(
    'the independent retail barcode fixture values pass identifier checks',
    () {
      final manifest =
          jsonDecode(
                File('test/fixtures/barcodes/manifest.json').readAsStringSync(),
              )
              as Map;
      var checked = 0;
      for (final fixture in manifest['fixtures'] as List) {
        final format = ScannedCodeFormat.fromStorageKey(
          fixture['symbolFormat'] as String,
        );
        if (![
          ScannedCodeFormat.upcA,
          ScannedCodeFormat.upcE,
          ScannedCodeFormat.ean8,
          ScannedCodeFormat.ean13,
        ].contains(format)) {
          continue;
        }
        final result = inspect(fixture['encodedValue'] as String, format)!;
        expect(
          result.validation,
          IdentifierValidation.checkDigitMatches,
          reason: fixture['id'] as String,
        );
        checked++;
      }
      expect(checked, 8);
    },
  );

  test('normalization and validation require no HTTP client', () {
    HttpOverrides.runZoned(() {
      expect(
        inspect('04252614', ScannedCodeFormat.upcE)!.derivedLookupValue,
        '042100005264',
      );
      expect(
        inspect(
          'ISBN: 0306406152',
          ScannedCodeFormat.qrCode,
        )!.derivedLookupValue,
        '9780306406157',
      );
    }, createHttpClient: (_) => throw StateError('Unexpected network access'));
  });
}
