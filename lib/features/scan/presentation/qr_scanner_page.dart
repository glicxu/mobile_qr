import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../create/application/qr_encoder.dart';
import '../../create/data/dart_qr_encoder.dart';
import '../../create/data/qr_png_renderer.dart';
import '../../secure_qr/domain/secure_qr_service.dart';
import '../../lookup/domain/gs1_digital_link.dart';
import '../../lookup/presentation/gs1_details.dart';
import '../../lookup/domain/identifier_recognizer.dart';
import '../../lookup/presentation/identifier_details.dart';
import '../application/scanned_code_verification.dart';
import '../data/mobile_scanner_code_adapter.dart';
import '../data/code_image_analyzer.dart';
import '../data/offline_image_decoder.dart';
import '../domain/qr_payload_classifier.dart';
import '../domain/scanned_code.dart';
import 'qr_payload_action.dart';
import 'qr_link_review.dart';

export '../application/scanned_code_verification.dart'
    show verificationForScannedCode;

final class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    required this.secureQrService,
    this.onScanned,
    this.sharedImagePath,
    this.onSharedImageConsumed,
    this.onCodeSelected,
    this.onBatchRequested,
    this.imageAnalyzer,
    this.scannerController,
    this.startCamera = true,
    this.imageError,
    this.imagePathPicker,
    super.key,
  });

  final SecureQrService secureQrService;
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
    required ScannedCodeFormat codeFormat,
    required ScanSource source,
  })?
  onScanned;
  final String? sharedImagePath;
  final ValueChanged<String>? onSharedImageConsumed;
  final ValueChanged<ScannedCode>? onCodeSelected;
  final Future<void> Function()? onBatchRequested;
  final CodeImageAnalyzer? imageAnalyzer;
  final MobileScannerController? scannerController;
  final bool startCamera;
  final String? imageError;
  final Future<String?> Function(ImageSource source)? imagePathPicker;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  static const _maxImageBytes = 25 * 1024 * 1024;
  static const QrEncoder _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  late final MobileScannerController _controller =
      widget.scannerController ??
      MobileScannerController(
        autoStart: widget.startCamera && widget.sharedImagePath == null,
        formats: MobileScannerCodeAdapter.formats,
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        returnImage: false,
      );
  final ImagePicker _imagePicker = ImagePicker();

  ScannedCode? _decodedCode;
  List<ScannedCode> _detectedCodes = const [];
  bool _handlingDetection = false;
  bool _importingImage = false;
  bool _selectionDelivered = false;
  bool _openingBatch = false;
  bool _binaryNoticeShown = false;
  int _imageGeneration = 0;
  late bool _cameraRequested;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _cameraRequested = _controller.autoStart;
    _imageError = widget.imageError;
    _scheduleSharedImage(widget.sharedImagePath);
  }

  @override
  void didUpdateWidget(covariant QrScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageError != oldWidget.imageError) {
      _imageError = widget.imageError;
    }
    if (widget.sharedImagePath != oldWidget.sharedImagePath) {
      _scheduleSharedImage(widget.sharedImagePath);
    }
  }

  void _scheduleSharedImage(String? path) {
    if (path == null || path.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.sharedImagePath != path) return;
      widget.onSharedImageConsumed?.call(path);
      unawaited(
        _scanImagePath(
          path,
          source: ScanSource.sharedImage,
          deleteAfterScan: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    if (widget.scannerController == null) unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handlingDetection || _openingBatch) return;

    final codes = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.camera,
    );
    if (codes.isEmpty) {
      if (!_binaryNoticeShown &&
          MobileScannerCodeAdapter.hasBinaryOnlyResults(capture)) {
        _binaryNoticeShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This code contains binary data without readable text. It cannot be opened or saved here.',
            ),
          ),
        );
      }
      return;
    }

    _handlingDetection = true;
    try {
      await _controller.pause();
    } on Object {
      // A decoded result remains usable if the camera has already stopped.
    }
    if (mounted) _completeDetection(codes.first);
  }

  void _completeDetection(ScannedCode code) {
    if (widget.onCodeSelected case final select?) {
      if (_selectionDelivered) return;
      _selectionDelivered = true;
      select(code);
      return;
    }
    setState(() {
      _decodedCode = code;
      _detectedCodes = const [];
    });
    final onScanned = widget.onScanned;
    if (onScanned != null &&
        !const QrPayloadClassifier().classify(code.value).isEphemeral) {
      final verification = verificationForScannedCode(
        widget.secureQrService,
        code,
      );
      Uint8List? qrPngBytes;
      if (code.format == ScannedCodeFormat.qrCode) {
        try {
          qrPngBytes = _pngRenderer
              .render(_encoder.encode(code.value), size: 512)
              .bytes;
        } on Object {
          // Very large or unsupported values can still be retained as text.
        }
      }
      unawaited(
        onScanned(
          payload: code.value,
          verificationCode: verification?.code,
          registrableDomain: verification is SecureQrResult
              ? verification.registrableDomain
              : null,
          qrPngBytes: qrPngBytes,
          codeFormat: code.format,
          source: code.source,
        ),
      );
    }
  }

  Future<void> _importImage() async {
    if (_handlingDetection || _importingImage) return;

    setState(() => _importingImage = true);
    _handlingDetection = true;
    try {
      try {
        await _controller.pause();
      } on Object {
        // Image import remains available when camera access is unavailable.
      }
      final String? path;
      if (widget.imagePathPicker case final pick?) {
        path = await pick(ImageSource.gallery);
      } else {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        path = image?.path;
      }
      if (path == null) {
        await _resumeAfterImport();
        return;
      }
      await _scanImagePath(path, source: ScanSource.gallery);
    } on Object {
      await _showImageScanError();
    }
  }

  Future<void> _scanImagePath(
    String path, {
    required ScanSource source,
    bool deleteAfterScan = false,
  }) async {
    final generation = ++_imageGeneration;
    _handlingDetection = true;
    if (mounted) {
      setState(() {
        _importingImage = true;
        _decodedCode = null;
        _detectedCodes = const [];
        _imageError = null;
      });
    }
    try {
      await _controller.pause();
    } on Object {
      // Still-image analysis does not need an active camera.
    }

    try {
      if (await File(path).length() > _maxImageBytes) {
        if (mounted && generation == _imageGeneration) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose an image smaller than 25 MB.'),
            ),
          );
          await _resumeAfterImport();
        }
        return;
      }
      final analysis =
          await (widget.imageAnalyzer ?? NativeCodeImageAnalyzer(_controller))
              .analyze(path, source: source);
      if (!mounted || generation != _imageGeneration) return;
      final codes = analysis.codes;
      if (codes.isEmpty) {
        _imageError =
            analysis.notice ??
            (analysis.binaryOnly
                ? 'This code contains binary data without readable text. It cannot be opened or saved here.'
                : 'No readable QR code or supported barcode was found. Try cropping closer to the code.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              analysis.notice ??
                  (analysis.binaryOnly
                      ? 'This code contains binary data without readable text. It cannot be opened or saved here.'
                      : 'No readable QR code or supported barcode was found. Try cropping closer to the code.'),
            ),
          ),
        );
        await _resumeAfterImport();
        return;
      }

      if (analysis.notice case final notice?) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
      setState(() => _importingImage = false);
      if (codes.length == 1) {
        _completeDetection(codes.single);
      } else {
        setState(() => _detectedCodes = codes);
      }
    } on ImageDecodeException catch (error) {
      if (mounted && generation == _imageGeneration) {
        _imageError = error.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        await _resumeAfterImport();
      }
    } on Object {
      if (generation == _imageGeneration) await _showImageScanError();
    } finally {
      if (deleteAfterScan) {
        try {
          await File(path).delete();
        } on Object {
          // Shared images live in cache and may already have been reclaimed.
        }
      }
    }
  }

  Future<void> _showImageScanError() async {
    if (!mounted) return;
    _imageError = 'The selected image could not be scanned.';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The selected image could not be scanned.')),
    );
    await _resumeAfterImport();
  }

  Future<void> _resumeAfterImport() async {
    if (!mounted) return;
    setState(() => _importingImage = false);
    _handlingDetection = false;
    if (!_cameraRequested || !_controller.value.hasCameraPermission) return;
    try {
      await _controller.start();
    } on Object {
      // The scanner widget reports camera startup failures in its error UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final decodedCode = _decodedCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code or barcode'),
        actions: [
          IconButton(
            tooltip: 'Supported formats',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Scan 13 code formats'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ScannedCodeFormat.values
                            .where(
                              (format) => format != ScannedCodeFormat.unknown,
                            )
                            .map((format) => format.label)
                            .join(', '),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Reads text locally. Center one code in the frame, especially Data Matrix. Use Choose image to scan an existing image. Binary-only payloads cannot be opened or saved.',
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onBatchRequested != null)
            IconButton(
              tooltip: 'Batch sessions',
              onPressed: _openingBatch || _importingImage
                  ? null
                  : () async {
                      if (_openingBatch ||
                          (_handlingDetection &&
                              _decodedCode == null &&
                              _detectedCodes.isEmpty)) {
                        return;
                      }
                      setState(() => _openingBatch = true);
                      try {
                        try {
                          await _controller.pause();
                        } on Object {
                          /* Stored sessions do not require camera access. */
                        }
                        await widget.onBatchRequested!();
                      } finally {
                        if (mounted) {
                          setState(() => _openingBatch = false);
                          if (_decodedCode == null && _detectedCodes.isEmpty) {
                            try {
                              await _controller.start();
                            } on Object {
                              /* Scanner error UI handles restart failures. */
                            }
                          }
                        }
                      }
                    },
              icon: const Icon(Icons.playlist_add_check),
            ),
          if (decodedCode == null && _detectedCodes.isEmpty)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) => IconButton(
                onPressed:
                    state.isRunning &&
                        state.torchState != TorchState.unavailable
                    ? () async {
                        try {
                          await _controller.toggleTorch();
                        } on Object {
                          // Camera shutdown can race a flashlight tap.
                        }
                      }
                    : null,
                tooltip: 'Toggle flashlight',
                icon: const Icon(Icons.flashlight_on_outlined),
              ),
            ),
        ],
      ),
      body: decodedCode != null
          ? _buildResult(context, decodedCode)
          : _detectedCodes.isNotEmpty
          ? _buildResultSelection(context)
          : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
            tapToFocus: true,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          const IgnorePointer(child: _ScannerGuide()),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xcc000000),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_imageError case final message?) ...[
                            Text(
                              message,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Text(
                            'Center a QR code or barcode. Reading stays on your device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!_cameraRequested)
                                FilledButton.tonalIcon(
                                  onPressed: _importingImage
                                      ? null
                                      : _scanAgain,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Start camera'),
                                ),
                              FilledButton.tonalIcon(
                                onPressed: _importingImage
                                    ? null
                                    : () => _importImage(),
                                icon: _importingImage
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.image_outlined),
                                label: Text(
                                  _importingImage
                                      ? 'Reading image...'
                                      : 'Choose image',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSelection(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Choose a result',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('More than one code was found in the image.'),
          const SizedBox(height: 16),
          for (final code in _detectedCodes)
            Card(
              child: ListTile(
                leading: const Icon(Icons.barcode_reader),
                title: Text(code.format.label),
                subtitle: Text(
                  const QrPayloadClassifier().classify(code.value).previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _completeDetection(code),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, ScannedCode code) {
    return ScannedCodeResultView(
      code: code,
      secureQrService: widget.secureQrService,
    );
  }

  Future<void> _scanAgain() async {
    ++_imageGeneration;
    setState(() {
      _cameraRequested = true;
      _imageError = null;
      _decodedCode = null;
      _detectedCodes = const [];
      _handlingDetection = false;
      _selectionDelivered = false;
      _binaryNoticeShown = false;
    });
    try {
      await _controller.start();
    } on Object {
      // The camera error view still offers image import.
    }
  }
}

final class ScannedCodeResultView extends StatelessWidget {
  const ScannedCodeResultView({
    required this.code,
    required this.secureQrService,
    this.onScanAgain,
    this.allowRouting = true,
    this.scanAgainLabel = 'Scan again',
    super.key,
  });

  static const _classifier = QrPayloadClassifier();

  final ScannedCode code;
  final SecureQrService secureQrService;
  final VoidCallback? onScanAgain;
  final bool allowRouting;
  final String scanAgainLabel;

  Future<void> _copyRawContent(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Contents copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final text = code.value;
    final payload = _classifier.classify(text);
    final digitalLink = const Gs1DigitalLinkParser().parse(text);
    final identifier = const IdentifierRecognizer().recognize(
      value: text,
      format: code.format,
    );
    final verification = verificationForScannedCode(secureQrService, code);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Center(
            child: Text(
              '${code.format.label} · ${switch (code.source) {
                ScanSource.camera => 'Scanned with camera',
                ScanSource.gallery => 'From photo library',
                ScanSource.sharedImage => 'From shared image',
              }}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            identifier != null && !payload.canRoute
                ? Icons.numbers
                : payload.icon,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          if (verification != null) ...[
            Text(
              'Verify if available',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              verification.code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              verification is SecureQrResult
                  ? verification.registrableDomain
                  : 'Content comparison code',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'If a trusted comparison code is printed beside the QR, '
              'compare it before opening.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              identifier == null ? payload.title : 'Identifier',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (identifier == null) ...[
              const SizedBox(height: 4),
              Text(
                payload.type == QrContentType.passkey
                    ? 'Your phone’s passkey provider handles verification.'
                    : 'No comparison code is available for this payload.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (digitalLink != null) ...[
            Gs1Details(link: digitalLink),
            const SizedBox(height: 16),
          ],
          if (identifier != null) ...[
            IdentifierDetails(recognition: identifier),
            const SizedBox(height: 16),
          ],
          if (payload.linkInspection case final inspection?
              when identifier == null || payload.canRoute) ...[
            QrLinkReview(inspection: inspection),
            const SizedBox(height: 16),
          ],
          if (allowRouting && payload.canRoute) ...[
            FilledButton.icon(
              onPressed: () => routeQrPayload(
                context,
                payload,
                comparisonCode: verification?.code,
              ),
              icon: Icon(payload.icon),
              label: Text(payload.actionLabel),
            ),
            const SizedBox(height: 8),
          ],
          if (onScanAgain != null) ...[
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(scanAgainLabel),
            ),
            const SizedBox(height: 8),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.info_outline),
            title: const Text('Details'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (verification != null) ...[
                      Text(
                        identifier == null
                            ? payload.title
                            : '${identifier.kind.label} candidate',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                    ],
                    SelectableText(
                      identifier == null
                          ? payload.primaryText
                          : identifier.originalValue,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final detail in payload.details) ...[
                      const SizedBox(height: 4),
                      SelectableText(detail),
                    ],
                    QrSensitiveDetail(payload: payload),
                    if (payload.type != QrContentType.passkey) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Raw content',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: QrRawContent(payload: payload),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _copyRawContent(context, text),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy contents'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dali QR has not opened or sent this value.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            permissionDenied
                ? 'Camera access is required to scan QR codes and barcodes. Enable it in system settings and return to the app.'
                : 'The camera could not start (${error.errorCode.name}).',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

final class _ScannerGuide extends StatelessWidget {
  const _ScannerGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
