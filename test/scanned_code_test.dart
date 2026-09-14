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
}
