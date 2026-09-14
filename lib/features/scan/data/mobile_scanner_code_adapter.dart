import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scanned_code.dart';

abstract final class MobileScannerCodeAdapter {
  static const formats = <BarcodeFormat>[
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
  ];

  static List<ScannedCode> extract(
    BarcodeCapture capture, {
    required ScanSource source,
  }) {
    final results = <ScannedCode>[];
    final seen = <(ScannedCodeFormat, String)>{};
    for (final barcode in capture.barcodes) {
      final format = _mapFormat(barcode.format);
      final value = barcode.rawValue;
      if (format == null || value == null || value.isEmpty) continue;
      if (!seen.add((format, value))) continue;
      results.add(
        ScannedCode(
          value: value,
          format: format,
          source: source,
          rawBytes: _decodedBytes(barcode.rawDecodedBytes),
        ),
      );
    }
    results.sort((a, b) {
      final formatOrder = a.format.index.compareTo(b.format.index);
      return formatOrder != 0 ? formatOrder : a.value.compareTo(b.value);
    });
    return List.unmodifiable(results);
  }

  static ScannedCodeFormat? _mapFormat(BarcodeFormat format) =>
      switch (format) {
        BarcodeFormat.qrCode => ScannedCodeFormat.qrCode,
        BarcodeFormat.upcA => ScannedCodeFormat.upcA,
        BarcodeFormat.upcE => ScannedCodeFormat.upcE,
        BarcodeFormat.ean8 => ScannedCodeFormat.ean8,
        BarcodeFormat.ean13 => ScannedCodeFormat.ean13,
        BarcodeFormat.code128 => ScannedCodeFormat.code128,
        BarcodeFormat.code39 => ScannedCodeFormat.code39,
        BarcodeFormat.code93 => ScannedCodeFormat.code93,
        BarcodeFormat.codabar => ScannedCodeFormat.codabar,
        BarcodeFormat.itf14 => ScannedCodeFormat.itf14,
        _ => null,
      };

  static Uint8List? _decodedBytes(BarcodeBytes? bytes) => switch (bytes) {
    DecodedBarcodeBytes(:final bytes) => bytes,
    DecodedVisionBarcodeBytes(:final bytes) => bytes,
    null => null,
  };
}
