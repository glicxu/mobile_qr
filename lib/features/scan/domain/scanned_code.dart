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
  unknown('unknown', 'Unknown format'),
  // Append values: existing enum positions and result priorities stay stable.
  dataMatrix('dataMatrix', 'Data Matrix'),
  pdf417('pdf417', 'PDF417'),
  aztec('aztec', 'Aztec');

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

List<ScannedCode> orderScannedCodes(Iterable<ScannedCode> codes) {
  final seen = <(ScannedCodeFormat, String)>{};
  final results = [
    for (final code in codes)
      if (seen.add((code.format, code.value))) code,
  ];
  results.sort((a, b) {
    final priority = a.format.index.compareTo(b.format.index);
    return priority != 0 ? priority : a.value.compareTo(b.value);
  });
  return List.unmodifiable(results);
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
