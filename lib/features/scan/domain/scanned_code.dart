import 'dart:typed_data';

enum ScannedCodeFormat {
  qrCode('qrCode', 'QR Code'),
  upcA('upcA', 'UPC-A'),
  upcE('upcE', 'UPC-E'),
  ean8('ean8', 'EAN-8'),
  ean13('ean13', 'EAN-13'),
  code128('code128', 'Code 128'),
  code39('code39', 'Code 39'),
  code93('code93', 'Code 93'),
  codabar('codabar', 'Codabar'),
  itf14('itf14', 'ITF-14'),
  unknown('unknown', 'Unknown format');

  const ScannedCodeFormat(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static ScannedCodeFormat fromStorageKey(String key) {
    return ScannedCodeFormat.values.firstWhere(
      (format) => format.storageKey == key,
      orElse: () => ScannedCodeFormat.unknown,
    );
  }
}

enum ScanSource {
  camera('Camera'),
  gallery('Photo library'),
  sharedImage('Shared image');

  const ScanSource(this.label);

  final String label;
}

final class ScannedCode {
  const ScannedCode({
    required this.value,
    required this.format,
    required this.source,
    this.rawBytes,
  });

  final String value;
  final ScannedCodeFormat format;
  final ScanSource source;
  final Uint8List? rawBytes;
}
