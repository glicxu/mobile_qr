import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/create/application/qr_encoder.dart';
import 'features/create/data/dart_qr_encoder.dart';
import 'features/create/data/qr_png_renderer.dart';
import 'features/create/domain/qr_matrix.dart';
import 'features/create/domain/qr_center_decoration.dart';
import 'features/create/domain/qr_creation_payload_policy.dart';
import 'features/history/application/history_controller.dart';
import 'features/history/presentation/history_page.dart';
import 'features/scan/presentation/qr_scanner_page.dart';
import 'features/secure_qr/application/secure_qr_loader.dart';
import 'features/secure_qr/domain/secure_qr_service.dart';

void main() => runApp(const DaliQrApp());

class DaliQrApp extends StatelessWidget {
  const DaliQrApp({this.secureQrService, this.historyController, super.key});

  final SecureQrService? secureQrService;
  final HistoryController? historyController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dali QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315caa)),
        useMaterial3: true,
      ),
      home: DaliQrHome(
        secureQrService: secureQrService,
        historyController: historyController,
      ),
    );
  }
}

class DaliQrHome extends StatefulWidget {
  const DaliQrHome({this.secureQrService, this.historyController, super.key});

  final SecureQrService? secureQrService;
  final HistoryController? historyController;

  @override
  State<DaliQrHome> createState() => _DaliQrHomeState();
}

class _DaliQrHomeState extends State<DaliQrHome> {
  int _selectedIndex = 0;
  late final Future<SecureQrService> _secureQrService;
  Future<HistoryController>? _historyController;

  @override
  void initState() {
    super.initState();
    final suppliedService = widget.secureQrService;
    _secureQrService = suppliedService == null
        ? SecureQrLoader.load()
        : Future.value(suppliedService);
    final suppliedHistory = widget.historyController;
    if (suppliedHistory != null) {
      _historyController = Future.value(suppliedHistory);
    }
  }

  Future<HistoryController> _loadHistory() {
    return _historyController ??= HistoryController.open();
  }

  Future<void> _recordCreated({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    required Uint8List qrPngBytes,
  }) async {
    await (await _loadHistory()).recordCreated(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
    );
  }

  Future<void> _recordScanned({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
  }) async {
    await (await _loadHistory()).recordScanned(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
    );
  }

  @override
  void dispose() {
    if (widget.historyController == null) {
      unawaited(_historyController?.then((controller) => controller.dispose()));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<SecureQrService>(
        future: _secureQrService,
        builder: (context, snapshot) {
          final service = snapshot.data;
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Secure QR data could not be loaded.'),
              ),
            );
          }
          if (service == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_selectedIndex) {
            0 => QrGenerationSpikePage(
              secureQrService: service,
              onCreated: _recordCreated,
            ),
            1 => QrScannerPage(
              secureQrService: service,
              onScanned: _recordScanned,
            ),
            _ => FutureBuilder<HistoryController>(
              future: _loadHistory(),
              builder: (context, historySnapshot) {
                final controller = historySnapshot.data;
                if (historySnapshot.hasError) {
                  return const Center(
                    child: Text('History could not be loaded.'),
                  );
                }
                return controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : HistoryPage(controller: controller);
              },
            ),
          };
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Create'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class QrGenerationSpikePage extends StatefulWidget {
  const QrGenerationSpikePage({
    required this.secureQrService,
    this.onCreated,
    super.key,
  });

  final SecureQrService secureQrService;
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    required Uint8List qrPngBytes,
  })?
  onCreated;

  @override
  State<QrGenerationSpikePage> createState() => _QrGenerationSpikePageState();
}

class _QrGenerationSpikePageState extends State<QrGenerationSpikePage> {
  static const _policy = QrCreationPayloadPolicy();
  static const _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();

  final _controller = TextEditingController(text: 'https://example.com/');
  QrCreationPayload? _payload;
  QrMatrix? _matrix;
  QrVerificationResult? _verification;
  Uint8List? _renderedQrBytes;
  String? _error;
  var _decorationMode = QrCenterDecorationMode.daliIcon;
  bool _generating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final payload = _policy.validate(_controller.text);
      final verification = widget.secureQrService.calculateForPayload(
        payload.value,
      );
      if (_decorationMode == QrCenterDecorationMode.verificationCode &&
          verification == null) {
        throw const FormatException(
          'This content has no comparison code to place in the QR.',
        );
      }
      final decorated = _decorationMode != QrCenterDecorationMode.none;
      final matrix = _encoder.encode(
        payload.value,
        strength: decorated
            ? QrEncodingStrength.decorated
            : QrEncodingStrength.standard,
      );
      final QrCenterDecoration? decoration;
      switch (_decorationMode) {
        case QrCenterDecorationMode.none:
          decoration = null;
        case QrCenterDecorationMode.verificationCode:
          decoration = QrCenterDecoration.verificationCode(verification!.code);
        case QrCenterDecorationMode.daliIcon:
          final asset = await rootBundle.load(
            'assets/dali_smart_code_icon.png',
          );
          decoration = QrCenterDecoration.daliIcon(
            asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
          );
      }
      final png = _pngRenderer.render(matrix, centerDecoration: decoration);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _matrix = matrix;
        _verification = verification;
        _renderedQrBytes = png.bytes;
        _error = null;
      });
      final onCreated = widget.onCreated;
      if (onCreated != null) {
        unawaited(
          onCreated(
            payload: payload.value,
            verificationCode: verification?.code,
            registrableDomain: verification is SecureQrResult
                ? verification.registrableDomain
                : null,
            qrPngBytes: png.bytes,
          ),
        );
      }
    } on QrCreationPayloadValidationException catch (error) {
      setState(() {
        _payload = null;
        _matrix = null;
        _verification = null;
        _renderedQrBytes = null;
        _error = error.message;
      });
    } on QrPayloadTooLongException {
      setState(() {
        _payload = null;
        _matrix = null;
        _verification = null;
        _renderedQrBytes = null;
        _error = 'This content is too large for a decorated Level H QR code.';
      });
    } on FormatException catch (error) {
      setState(() {
        _payload = null;
        _matrix = null;
        _verification = null;
        _renderedQrBytes = null;
        _error = error.message;
      });
    } on Object catch (error) {
      setState(() {
        _payload = null;
        _matrix = null;
        _verification = null;
        _renderedQrBytes = null;
        _error = 'QR generation failed: $error';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _matrix;
    final payload = _payload;
    final renderedQrBytes = _renderedQrBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('Create QR code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'QR content',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _generate(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<QrCenterDecorationMode>(
              segments: const [
                ButtonSegment(
                  value: QrCenterDecorationMode.none,
                  icon: Icon(Icons.qr_code_2),
                  label: Text('Plain'),
                ),
                ButtonSegment(
                  value: QrCenterDecorationMode.verificationCode,
                  icon: Icon(Icons.verified_outlined),
                  label: Text('Code'),
                ),
                ButtonSegment(
                  value: QrCenterDecorationMode.daliIcon,
                  icon: Icon(Icons.shield_outlined),
                  label: Text('Icon'),
                ),
              ],
              selected: {_decorationMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _decorationMode = selection.single;
                  _payload = null;
                  _matrix = null;
                  _verification = null;
                  _renderedQrBytes = null;
                });
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _generating ? null : () => unawaited(_generate()),
              child: Text(_generating ? 'Generating...' : 'Generate QR code'),
            ),
            if (matrix != null &&
                payload != null &&
                renderedQrBytes != null) ...[
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  label: 'QR code for ${payload.value}',
                  image: true,
                  child: SizedBox.square(
                    dimension: 320,
                    child: Image.memory(
                      renderedQrBytes,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_verification case final verification?) ...[
                Text(
                  verification.code,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verification is SecureQrResult
                      ? 'Secure QR · ${verification.registrableDomain}'
                      : 'Content comparison code',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'No verification code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  payload.webUrl == null
                      ? 'This payload type has no verification scheme.'
                      : 'This URL does not have a registrable domain.',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              SelectableText(payload.value),
            ],
          ],
        ),
      ),
    );
  }
}
