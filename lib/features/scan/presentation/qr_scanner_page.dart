import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  static const QrEncoder _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  static const _classifier = QrPayloadClassifier();

  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    returnImage: false,
  );

  String? _decodedText;
  bool _handlingDetection = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handlingDetection) return;

    String? text;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue;
      if (candidate != null && candidate.isNotEmpty) {
        text = candidate;
        break;
      }
    }
    if (text == null) return;

    _handlingDetection = true;
    unawaited(_controller.pause());
    setState(() => _decodedText = text);
    final onScanned = widget.onScanned;
    if (onScanned != null) {
      final verification = widget.secureQrService.calculateForPayload(text);
      Uint8List? qrPngBytes;
      try {
        qrPngBytes = _pngRenderer
            .render(_encoder.encode(text), size: 512)
            .bytes;
      } on Object {
        // Very large or unsupported values can still be retained as text.
      }
      unawaited(
        onScanned(
          payload: text,
          verificationCode: verification?.code,
          registrableDomain: verification is SecureQrResult
              ? verification.registrableDomain
              : null,
          qrPngBytes: qrPngBytes,
        ),
      );
    }
  }

  Future<void> _scanAgain() async {
    setState(() => _decodedText = null);
    _handlingDetection = false;
    await _controller.start();
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
          const Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xcc000000),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Point the camera at a QR code. Nothing is opened or sent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
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
              'No comparison code is available for this payload.',
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
          const SizedBox(height: 12),
          const Text(
            'The decoded value is displayed only. Dali QR has not opened or sent it.',
          ),
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
