import 'dart:typed_data';

import 'package:dali_qr/features/scan/data/mobile_scanner_code_adapter.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  test('allowlist contains QR and all version 1.2 formats', () {
    expect(MobileScannerCodeAdapter.formats, [
      BarcodeFormat.qrCode,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.itf14,
    ]);
  });

  test('extracts, maps, sorts, and deduplicates supported results', () {
    const capture = BarcodeCapture(
      barcodes: [
        Barcode(format: BarcodeFormat.code128, rawValue: 'shipping'),
        Barcode(format: BarcodeFormat.qrCode, rawValue: 'https://example.com'),
        Barcode(format: BarcodeFormat.code128, rawValue: 'shipping'),
        Barcode(format: BarcodeFormat.upcA, rawValue: '012345678905'),
      ],
    );

    final results = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.gallery,
    );

    expect(results.map((result) => result.format), [
      ScannedCodeFormat.qrCode,
      ScannedCodeFormat.upcA,
      ScannedCodeFormat.code128,
    ]);
    expect(results.map((result) => result.value), [
      'https://example.com',
      '012345678905',
      'shipping',
    ]);
    expect(
      results.every((result) => result.source == ScanSource.gallery),
      true,
    );
  });

  test('ignores unsupported, null, and empty results', () {
    const capture = BarcodeCapture(
      barcodes: [
        Barcode(format: BarcodeFormat.pdf417, rawValue: 'unsupported'),
        Barcode(format: BarcodeFormat.qrCode),
        Barcode(format: BarcodeFormat.code39, rawValue: ''),
      ],
    );

    expect(
      MobileScannerCodeAdapter.extract(capture, source: ScanSource.camera),
      isEmpty,
    );
  });

  test('preserves leading zeroes and decoded bytes', () {
    final capture = BarcodeCapture(
      barcodes: [
        Barcode(
          format: BarcodeFormat.ean13,
          rawValue: '0012345678905',
          rawDecodedBytes: DecodedBarcodeBytes(
            bytes: Uint8List.fromList([1, 2]),
          ),
        ),
      ],
    );

    final result = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.sharedImage,
    ).single;

    expect(result.value, '0012345678905');
    expect(result.rawBytes, [1, 2]);
    expect(result.source, ScanSource.sharedImage);
  });
}
