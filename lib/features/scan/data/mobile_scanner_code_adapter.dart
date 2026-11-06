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
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
    BarcodeFormat.aztec,
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
      // ML Kit's FORMAT_ITF is generic Interleaved 2 of 5, despite the plugin's
      // itf14 enum name. Do not label shorter/other ITF payloads as ITF-14.
      if (format == ScannedCodeFormat.itf14 &&
          !RegExp(r'^[0-9]{14}$').hasMatch(value)) {
        continue;
      }
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
    return orderScannedCodes(results);
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
        BarcodeFormat.dataMatrix => ScannedCodeFormat.dataMatrix,
        BarcodeFormat.pdf417 => ScannedCodeFormat.pdf417,
        BarcodeFormat.aztec => ScannedCodeFormat.aztec,
        _ => null,
      };

  static bool hasBinaryOnlyResults(BarcodeCapture capture) =>
      capture.barcodes.any(
        (barcode) =>
            _mapFormat(barcode.format) != null &&
            (barcode.rawValue == null || barcode.rawValue!.isEmpty) &&
            (_decodedBytes(barcode.rawDecodedBytes)?.isNotEmpty ?? false),
      );

  static Uint8List? _decodedBytes(BarcodeBytes? bytes) => switch (bytes) {
    DecodedBarcodeBytes(:final bytes) => bytes,
    DecodedVisionBarcodeBytes(:final bytes) => bytes,
    null => null,
  };
}
