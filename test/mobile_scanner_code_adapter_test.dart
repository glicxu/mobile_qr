import 'dart:typed_data';

import 'package:dali_qr/features/scan/data/mobile_scanner_code_adapter.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  test(
    'allowlist contains QR, existing 1D formats, and the three additional 2D formats',
    () {
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
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
        BarcodeFormat.aztec,
      ]);
    },
  );

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
        Barcode(format: BarcodeFormat.unknown, rawValue: 'unsupported'),
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

  test('all supported mappings preserve exact values across each source', () {
    const mappings = {
      BarcodeFormat.qrCode: ScannedCodeFormat.qrCode,
      BarcodeFormat.upcA: ScannedCodeFormat.upcA,
      BarcodeFormat.upcE: ScannedCodeFormat.upcE,
      BarcodeFormat.ean8: ScannedCodeFormat.ean8,
      BarcodeFormat.ean13: ScannedCodeFormat.ean13,
      BarcodeFormat.code128: ScannedCodeFormat.code128,
      BarcodeFormat.code39: ScannedCodeFormat.code39,
      BarcodeFormat.code93: ScannedCodeFormat.code93,
      BarcodeFormat.codabar: ScannedCodeFormat.codabar,
      BarcodeFormat.itf14: ScannedCodeFormat.itf14,
      BarcodeFormat.dataMatrix: ScannedCodeFormat.dataMatrix,
      BarcodeFormat.pdf417: ScannedCodeFormat.pdf417,
      BarcodeFormat.aztec: ScannedCodeFormat.aztec,
    };
    for (final source in ScanSource.values) {
      for (final mapping in mappings.entries) {
        final value = mapping.value == ScannedCodeFormat.itf14
            ? '10012345000017'
            : '  00123\n';
        final results = MobileScannerCodeAdapter.extract(
          BarcodeCapture(
            barcodes: [Barcode(format: mapping.key, rawValue: value)],
          ),
          source: source,
        );
        expect(results.single.format, mapping.value);
        expect(results.single.value, value);
        expect(results.single.source, source);
      }
    }
  });

  test(
    'preserves distinct Unicode representations and whitespace-only data',
    () {
      const capture = BarcodeCapture(
        barcodes: [
          Barcode(format: BarcodeFormat.qrCode, rawValue: '\u00e9'),
          Barcode(format: BarcodeFormat.qrCode, rawValue: 'e\u0301'),
          Barcode(format: BarcodeFormat.qrCode, rawValue: '   '),
        ],
      );
      final results = MobileScannerCodeAdapter.extract(
        capture,
        source: ScanSource.gallery,
      );
      expect(results.map((code) => code.value), ['   ', 'e\u0301', '\u00e9']);
    },
  );
  test('generic ITF lengths cannot masquerade as ITF-14', () {
    final capture = BarcodeCapture(
      barcodes: [
        for (final value in [
          '123456',
          '123456789012',
          '1234567890123456',
          ' 10012345000017',
        ])
          Barcode(format: BarcodeFormat.itf14, rawValue: value),
      ],
    );
    expect(
      MobileScannerCodeAdapter.extract(capture, source: ScanSource.camera),
      isEmpty,
    );
  });
}
