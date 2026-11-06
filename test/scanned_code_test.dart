import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format storage keys round trip', () {
    for (final format in ScannedCodeFormat.values) {
      expect(ScannedCodeFormat.fromStorageKey(format.storageKey), same(format));
      expect(format.label, isNotEmpty);
    }
  });

  test('unknown stored format does not masquerade as QR', () {
    expect(
      ScannedCodeFormat.fromStorageKey('future-format'),
      ScannedCodeFormat.unknown,
    );
  });
  test(
    'adding 2D formats retains all existing format positions and stable keys',
    () {
      expect(
        ScannedCodeFormat.values.take(11).map((format) => format.storageKey),
        [
          'qrCode',
          'upcA',
          'upcE',
          'ean8',
          'ean13',
          'code128',
          'code39',
          'code93',
          'codabar',
          'itf14',
          'unknown',
        ],
      );
      expect(
        ScannedCodeFormat.values.skip(11).map((format) => format.storageKey),
        ['dataMatrix', 'pdf417', 'aztec'],
      );
    },
  );
}
