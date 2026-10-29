import 'package:dali_qr/features/scan/data/mobile_scanner_code_adapter.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
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

    final result = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.gallery,
    ).single;
    expect(result.value, 'https://example.com/from-image');
    expect(result.format, ScannedCodeFormat.qrCode);
  });

  test('image import accepts supported 1D barcode formats', () {
    const capture = BarcodeCapture(
      barcodes: [Barcode(format: BarcodeFormat.code128, rawValue: 'not-a-qr')],
    );

    final result = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.gallery,
    ).single;
    expect(result.value, 'not-a-qr');
    expect(result.format, ScannedCodeFormat.code128);
  });
}
