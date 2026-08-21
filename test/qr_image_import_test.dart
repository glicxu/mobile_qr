import 'package:dali_qr/features/scan/presentation/qr_scanner_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  test('image import selects the first non-empty QR payload', () {
    const capture = BarcodeCapture(
      barcodes: [
        Barcode(format: BarcodeFormat.qrCode, rawValue: ''),
        Barcode(
          format: BarcodeFormat.qrCode,
          rawValue: 'https://example.com/from-image',
        ),
      ],
    );

    expect(firstQrPayload(capture), 'https://example.com/from-image');
  });

  test('image import ignores other barcode formats', () {
    const capture = BarcodeCapture(
      barcodes: [Barcode(format: BarcodeFormat.code128, rawValue: 'not-a-qr')],
    );

    expect(firstQrPayload(capture), isNull);
  });
}
