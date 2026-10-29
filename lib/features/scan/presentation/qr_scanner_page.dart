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
import '../domain/qr_payload_classifier.dart';
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
  })?
  onScanned;
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
  })?
  onSave;
  final String? sharedImagePath;
  final ValueChanged<String>? onSharedImageConsumed;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  static const QrEncoder _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  static const _classifier = QrPayloadClassifier();

  late final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    returnImage: false,
  );
  final ImagePicker _imagePicker = ImagePicker();

  String? _decodedText;
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
      unawaited(_scanImagePath(path, deleteAfterScan: true));
    });
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handlingDetection) return;

    final text = firstQrPayload(capture);
    if (text == null) return;

    _handlingDetection = true;
    unawaited(_controller.pause());
    _completeDetection(text);
  }

  void _completeDetection(String text) {
    setState(() {
      _decodedText = text;
      _saved = false;
      _decodedQrPngBytes = null;
    });
    final onScanned = widget.onScanned;
    if (onScanned != null &&
        _classifier.classify(text).type != QrContentType.passkey) {
      final verification = widget.secureQrService.calculateForPayload(text);
      Uint8List? qrPngBytes;
      try {
        qrPngBytes = _pngRenderer
            .render(_encoder.encode(text), size: 512)
            .bytes;
      } on Object {
        // Very large or unsupported values can still be retained as text.
      }
      _decodedQrPngBytes = qrPngBytes;
      _recordingFuture = onScanned(
        payload: text,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: qrPngBytes,
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
      await _scanImagePath(image.path);
    } on Object {
      await _showImageScanError();
    }
  }

  Future<void> _scanImagePath(
    String path, {
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
      final capture = await _controller.analyzeImage(path);
      if (!mounted) return;
      final text = capture == null ? null : firstQrPayload(capture);
      if (text == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readable QR code was found in that image.'),
          ),
        );
        await _resumeAfterImport();
        return;
      }

      setState(() => _importingImage = false);
      _completeDetection(text);
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
      _decodedText = null;
      _decodedQrPngBytes = null;
      _saved = false;
    });
    _handlingDetection = false;
    await _controller.start();
  }

  Future<void> _copyRawContent(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Raw content copied.')));
  }

  Future<void> _saveQr(String text) async {
    final onSave = widget.onSave;
    if (onSave == null || _saving || _saved) return;
    setState(() => _saving = true);
    try {
      await _recordingFuture;
      final verification = widget.secureQrService.calculateForPayload(text);
      await onSave(
        payload: text,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: _decodedQrPngBytes,
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR saved.')));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The QR could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decodedText = _decodedText;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code'),
        actions: [
          if (decodedText == null)
            IconButton(
              onPressed: _controller.toggleTorch,
              tooltip: 'Toggle flashlight',
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
        ],
      ),
      body: decodedText == null
          ? _buildScanner()
          : _buildResult(context, decodedText),
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
                        'Point the camera at a QR code. Nothing is opened or sent.',
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

  Widget _buildResult(BuildContext context, String text) {
    final payload = _classifier.classify(text);
    final verification = widget.secureQrService.calculateForPayload(text);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                  ? 'Your phone’s passkey provider handles verification.'
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving || _saved ? null : () => _saveQr(text),
                icon: Icon(
                  _saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _saved
                      ? 'Saved'
                      : 'Save QR',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _copyRawContent(text),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy raw content'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The decoded value is displayed only. Dali QR has not opened or sent it.',
            ),
          ],
          const SizedBox(height: 24),
          if (payload.canRoute) ...[
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
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
String? firstQrPayload(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    if (barcode.format != BarcodeFormat.qrCode) continue;
    final candidate = barcode.rawValue;
    if (candidate != null && candidate.isNotEmpty) return candidate;
  }
  return null;
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
                ? 'Camera access is required to scan QR codes. Enable it in system settings and return to the app.'
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
