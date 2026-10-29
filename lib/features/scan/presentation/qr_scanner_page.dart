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
import '../data/mobile_scanner_code_adapter.dart';
import '../domain/qr_payload_classifier.dart';
import '../domain/scanned_code.dart';
import 'qr_payload_action.dart';

final class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    required this.secureQrService,
    this.onScanned,
    this.onSave,
    this.sharedImagePath,
    this.onSharedImageConsumed,
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
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
    required ScannedCodeFormat codeFormat,
    required ScanSource source,
  })?
  onSave;
  final String? sharedImagePath;
  final ValueChanged<String>? onSharedImageConsumed;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  static const _maxImageBytes = 25 * 1024 * 1024;
  static const QrEncoder _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    formats: MobileScannerCodeAdapter.formats,
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    returnImage: false,
  );
  final ImagePicker _imagePicker = ImagePicker();

  ScannedCode? _decodedCode;
  List<ScannedCode> _detectedCodes = const [];
  Uint8List? _decodedQrPngBytes;
  bool _handlingDetection = false;
  bool _importingImage = false;
  bool _saving = false;
  bool _saved = false;
  Future<void>? _recordingFuture;

  @override
  void initState() {
    super.initState();
    _scheduleSharedImage(widget.sharedImagePath);
  }

  @override
  void didUpdateWidget(covariant QrScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handlingDetection) return;

    final codes = MobileScannerCodeAdapter.extract(
      capture,
      source: ScanSource.camera,
    );
    if (codes.isEmpty) return;

    _handlingDetection = true;
    unawaited(_controller.pause());
    _completeDetection(codes.first);
  }

  void _completeDetection(ScannedCode code) {
    _recordingFuture = null;
    setState(() {
      _decodedCode = code;
      _detectedCodes = const [];
      _saved = false;
      _decodedQrPngBytes = null;
    });
    final onScanned = widget.onScanned;
    if (onScanned != null &&
        const QrPayloadClassifier().classify(code.value).type !=
            QrContentType.passkey) {
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
      _decodedQrPngBytes = qrPngBytes;
      _recordingFuture = onScanned(
        payload: code.value,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: qrPngBytes,
        codeFormat: code.format,
        source: code.source,
      );
      unawaited(_recordingFuture);
    }
  }

  Future<void> _importImage() async {
    if (_handlingDetection || _importingImage) return;

    setState(() => _importingImage = true);
    _handlingDetection = true;
    try {
      await _controller.pause();
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (image == null) {
        await _resumeAfterImport();
        return;
      }
      await _scanImagePath(image.path, source: ScanSource.gallery);
    } on Object {
      await _showImageScanError();
    }
  }

  Future<void> _scanImagePath(
    String path, {
    required ScanSource source,
    bool deleteAfterScan = false,
  }) async {
    if (!_handlingDetection) {
      _handlingDetection = true;
      if (mounted) setState(() => _importingImage = true);
      try {
        await _controller.pause();
      } on Object {
        // Image analysis does not require a running camera.
      }
    }

    try {
      if (await File(path).length() > _maxImageBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose an image smaller than 25 MB.'),
            ),
          );
          await _resumeAfterImport();
        }
        return;
      }
      final capture = await _controller.analyzeImage(path);
      if (!mounted) return;
      final codes = capture == null
          ? const <ScannedCode>[]
          : MobileScannerCodeAdapter.extract(capture, source: source);
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable QR code or supported barcode was found in that image.',
            ),
          ),
        );
        await _resumeAfterImport();
        return;
      }

      setState(() => _importingImage = false);
      if (codes.length == 1) {
        _completeDetection(codes.single);
      } else {
        setState(() => _detectedCodes = codes);
      }
    } on Object {
      await _showImageScanError();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The selected image could not be scanned.')),
    );
    await _resumeAfterImport();
  }

  Future<void> _resumeAfterImport() async {
    if (!mounted) return;
    setState(() => _importingImage = false);
    _handlingDetection = false;
    try {
      await _controller.start();
    } on Object {
      // The scanner widget reports camera startup failures in its error UI.
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _decodedCode = null;
      _detectedCodes = const [];
      _decodedQrPngBytes = null;
      _saved = false;
    });
    _handlingDetection = false;
    await _controller.start();
  }

  Future<void> _saveCode(ScannedCode code) async {
    final onSave = widget.onSave;
    if (onSave == null || _saving || _saved) return;
    setState(() => _saving = true);
    try {
      await _recordingFuture;
      final verification = verificationForScannedCode(
        widget.secureQrService,
        code,
      );
      await onSave(
        payload: code.value,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: _decodedQrPngBytes,
        codeFormat: code.format,
        source: code.source,
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code saved.')));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The code could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decodedCode = _decodedCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code or barcode'),
        actions: [
          if (decodedCode == null && _detectedCodes.isEmpty)
            IconButton(
              onPressed: _controller.toggleTorch,
              tooltip: 'Toggle flashlight',
              icon: const Icon(Icons.flashlight_on_outlined),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Point the camera at a QR code or barcode. Nothing is opened or sent.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _importingImage ? null : _importImage,
                        icon: _importingImage
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          _importingImage ? 'Reading image...' : 'Choose image',
                        ),
                      ),
                    ],
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
                  code.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _completeDetection(code),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, ScannedCode code) {
    return ScannedCodeResultView(
      code: code,
      secureQrService: widget.secureQrService,
      saving: _saving,
      saved: _saved,
      onSave: () => _saveCode(code),
      onScanAgain: _scanAgain,
    );
  }
}

final class ScannedCodeResultView extends StatelessWidget {
  const ScannedCodeResultView({
    required this.code,
    required this.secureQrService,
    required this.onScanAgain,
    this.onSave,
    this.saving = false,
    this.saved = false,
    this.allowRouting = true,
    this.scanAgainLabel = 'Scan again',
    super.key,
  });

  static const _classifier = QrPayloadClassifier();

  final ScannedCode code;
  final SecureQrService secureQrService;
  final VoidCallback onScanAgain;
  final VoidCallback? onSave;
  final bool saving;
  final bool saved;
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
    final verification = verificationForScannedCode(secureQrService, code);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Chip(
                  avatar: const Icon(Icons.barcode_reader),
                  label: Text(code.format.label),
                ),
                Text(
                  code.source.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Icon(
            payload.icon,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          if (verification != null) ...[
            Text(
              'VERIFY IF AVAILABLE',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              verification.code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              verification is SecureQrResult
                  ? verification.registrableDomain
                  : 'Content comparison code',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'If a trusted comparison code is printed beside the QR, '
              'compare it before opening.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
          ] else ...[
            Text(
              payload.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              payload.type == QrContentType.passkey
                  ? 'Your phone?s passkey provider handles verification.'
                  : 'No comparison code is available for this payload.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
          ],
          Text(payload.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          SelectableText(
            payload.primaryText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final detail in payload.details) ...[
            const SizedBox(height: 4),
            SelectableText(detail),
          ],
          QrSensitiveDetail(payload: payload),
          if (payload.type != QrContentType.passkey) ...[
            const SizedBox(height: 20),
            Text('Raw content', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text),
              ),
            ),
            if (onSave != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: saving || saved ? null : onSave,
                  icon: Icon(
                    saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : saved
                        ? 'Saved'
                        : 'Save code',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _copyRawContent(context, text),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy contents'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The decoded value is displayed only. Dali QR has not opened or sent it.',
            ),
          ],
          const SizedBox(height: 24),
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
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(scanAgainLabel),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
QrVerificationResult? verificationForScannedCode(
  SecureQrService service,
  ScannedCode code,
) {
  if (code.format != ScannedCodeFormat.qrCode) return null;
  return service.calculateForPayload(code.value);
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
