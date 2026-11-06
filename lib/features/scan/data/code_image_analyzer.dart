import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scanned_code.dart';
import 'mobile_scanner_code_adapter.dart';
import 'offline_image_decoder.dart';

final class CodeImageAnalysis {
  const CodeImageAnalysis(this.codes, {this.notice, this.binaryOnly = false});
  final List<ScannedCode> codes;
  final String? notice;
  final bool binaryOnly;
}

abstract interface class CodeImageAnalyzer {
  Future<CodeImageAnalysis> analyze(String path, {required ScanSource source});
}

final class NativeCodeImageAnalyzer implements CodeImageAnalyzer {
  const NativeCodeImageAnalyzer(
    this.controller, {
    this.fallback = const OfflineImageDecoder(),
  });
  final MobileScannerController controller;
  final OfflineImageDecoder fallback;

  @override
  Future<CodeImageAnalysis> analyze(
    String path, {
    required ScanSource source,
  }) async {
    // Fallback is always attempted for the additional 2D formats: ML Kit can
    // miss a small Aztec or an off-center Data Matrix even when it found a QR.
    // The independent fallback has its own pixel and execution bounds.
    final additional = fallback.decodeFile(path, source: source);
    // Attach an error handler immediately while the native request is pending.
    String? notice;
    final extra = additional.catchError((Object error) {
      notice = error is ImageDecodeException
          ? error.message
          : 'Some codes could not be read. Try cropping the image.';
      return <ScannedCode>[];
    });
    BarcodeCapture? capture;
    try {
      capture = await controller
          .analyzeImage(path, formats: MobileScannerCodeAdapter.formats)
          .timeout(const Duration(seconds: 8));
    } on Object {
      // Local fallback may still recover a supported 2D code.
    }
    final codes = orderScannedCodes([
      if (capture != null)
        ...MobileScannerCodeAdapter.extract(capture, source: source),
      ...await extra,
    ]);
    return CodeImageAnalysis(
      codes,
      notice: notice,
      binaryOnly:
          capture != null &&
          MobileScannerCodeAdapter.hasBinaryOnlyResults(capture),
    );
  }
}
