import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'features/create/application/qr_encoder.dart';
import 'features/create/application/qr_png_validator.dart';
import 'features/create/data/dart_qr_encoder.dart';
import 'features/create/data/qr_png_renderer.dart';
import 'features/create/domain/qr_center_decoration.dart';
import 'features/create/domain/qr_creation_payload_policy.dart';
import 'features/create/domain/qr_matrix.dart';
import 'features/create/domain/wifi_qr_payload.dart';
import 'features/create/domain/structured_qr_payload.dart';
import 'features/create/presentation/structured_qr_fields.dart';
import 'features/create/presentation/wifi_qr_fields.dart';
import 'features/create/presentation/generated_qr_page.dart';
import 'features/create/application/barcode_generator.dart';
import 'features/create/presentation/generated_barcode_page.dart';
import 'features/history/application/history_controller.dart';
import 'features/history/domain/qr_history.dart';
import 'features/history/presentation/history_page.dart';
import 'features/create/application/custom_center_image_store.dart';
import 'features/create/presentation/image_crop_page.dart';
import 'features/monetization/application/customization_entitlement.dart';
import 'features/scan/application/inbound_image_share.dart';
import 'features/scan/domain/scanned_code.dart';
import 'features/scan/domain/qr_payload_classifier.dart';
import 'features/scan/presentation/qr_scanner_page.dart';
import 'features/scan/presentation/share_extension_result_app.dart';
import 'features/secure_qr/application/secure_qr_loader.dart';
import 'features/secure_qr/domain/secure_qr_service.dart';
import 'features/batch/presentation/batch_sessions_page.dart';
import 'features/batch/application/batch_export.dart';
import 'features/payments/application/payments_entitlement.dart';

void main(List<String> arguments) => runApp(
  DaliQrApp(initialSharedLaunch: arguments.contains('--dali-shared-image')),
);

@pragma('vm:entry-point')
void shareExtensionMain() => runDaliQrShareExtension();

class DaliQrApp extends StatelessWidget {
  const DaliQrApp({
    this.secureQrService,
    this.historyController,
    this.customizationEntitlement,
    this.customCenterImageStore,
    this.inboundImageShare,
    this.paymentsEntitlement,
    this.initialSharedLaunch = false,
    super.key,
  });

  final SecureQrService? secureQrService;
  final HistoryController? historyController;
  final CustomizationEntitlement? customizationEntitlement;
  final CustomCenterImageStore? customCenterImageStore;
  final InboundImageShareSource? inboundImageShare;
  final PaymentsEntitlement? paymentsEntitlement;
  final bool initialSharedLaunch;

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
        customizationEntitlement: customizationEntitlement,
        customCenterImageStore: customCenterImageStore,
        inboundImageShare: inboundImageShare,
        paymentsEntitlement: paymentsEntitlement,
        initialSharedLaunch: initialSharedLaunch,
      ),
    );
  }
}

class DaliQrHome extends StatefulWidget {
  const DaliQrHome({
    this.secureQrService,
    this.historyController,
    this.customizationEntitlement,
    this.customCenterImageStore,
    this.inboundImageShare,
    this.paymentsEntitlement,
    this.initialSharedLaunch = false,
    super.key,
  });

  final SecureQrService? secureQrService;
  final HistoryController? historyController;
  final CustomizationEntitlement? customizationEntitlement;
  final CustomCenterImageStore? customCenterImageStore;
  final InboundImageShareSource? inboundImageShare;
  final PaymentsEntitlement? paymentsEntitlement;
  final bool initialSharedLaunch;

  @override
  State<DaliQrHome> createState() => _DaliQrHomeState();
}

class _DaliQrHomeState extends State<DaliQrHome> {
  int _selectedIndex = 1;
  int _scanSession = 0;
  final _createNavigatorKey = GlobalKey<NavigatorState>();
  late final Future<SecureQrService> _secureQrService;
  Future<HistoryController>? _historyController;
  late final Future<CustomizationEntitlement> _customizationEntitlement;
  late final CustomCenterImageStore _customCenterImageStore;
  Future<PackageInfo>? _packageInfo;
  late final InboundImageShareSource _inboundImageShare;
  String? _sharedImagePath;
  String? _sharedImageError;
  bool _inboundShareReady = false;
  late bool _imageOnlyLaunch;

  @override
  void initState() {
    super.initState();
    _imageOnlyLaunch = widget.initialSharedLaunch;
    unawaited(BatchExport.cleanupStale().catchError((Object _) {}));
    final suppliedService = widget.secureQrService;
    _secureQrService = suppliedService == null
        ? SecureQrLoader.load()
        : Future.value(suppliedService);
    final suppliedHistory = widget.historyController;
    if (suppliedHistory != null) {
      _historyController = Future.value(suppliedHistory);
    }
    final suppliedEntitlement = widget.customizationEntitlement;
    _customizationEntitlement = suppliedEntitlement == null
        ? StoreCustomizationEntitlement.open()
        : Future.value(suppliedEntitlement);
    _customCenterImageStore =
        widget.customCenterImageStore ?? CustomCenterImageStore();
    unawaited(_customCenterImageStore.initialize());
    _inboundImageShare =
        widget.inboundImageShare ??
        InboundImageShare(
          onError: (message) {
            if (!mounted) return;
            setState(() {
              _sharedImageError = message;
              _imageOnlyLaunch = true;
              _sharedImagePath = null;
              _selectedIndex = 1;
              _scanSession++;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            });
          },
        );
    unawaited(
      _inboundImageShare
          .start(_receiveSharedImage)
          .then(
            (_) {
              if (mounted) setState(() => _inboundShareReady = true);
            },
            onError: (Object _) {
              if (mounted) setState(() => _inboundShareReady = true);
            },
          ),
    );
  }

  void _receiveSharedImage(String path) {
    if (!mounted) return;
    setState(() {
      _sharedImagePath = path;
      _imageOnlyLaunch = true;
      _sharedImageError = null;
      _selectedIndex = 1;
    });
  }

  void _sharedImageConsumed(String path) {
    if (!mounted || _sharedImagePath != path) return;
    setState(() => _sharedImagePath = null);
  }

  Future<HistoryController> _loadHistory() {
    return _historyController ??= HistoryController.open();
  }

  Future<PackageInfo> _loadPackageInfo() {
    return _packageInfo ??= PackageInfo.fromPlatform();
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

  Future<void> _recordBarcodeCreated(GeneratedBarcode code) async {
    if (const QrPayloadClassifier().classify(code.value).isEphemeral) {
      return;
    }
    await (await _loadHistory()).recordCreated(
      payload: code.value,
      codeFormat: code.format,
    );
  }

  Future<void> _saveBarcodeCreated(GeneratedBarcode code) async {
    if (const QrPayloadClassifier().classify(code.value).isEphemeral) {
      return;
    }
    await (await _loadHistory()).savePayload(
      payload: code.value,
      codeFormat: code.format,
      activityKind: QrActivityKind.created,
      source: QrActivitySource.manual,
    );
  }

  Future<void> _recordScanned({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
    required ScannedCodeFormat codeFormat,
    required ScanSource source,
  }) async {
    await (await _loadHistory()).recordScanned(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
      codeFormat: codeFormat,
      source: source,
    );
  }

  Future<void> _saveCreated({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
  }) async {
    await (await _loadHistory()).savePayload(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
      activityKind: QrActivityKind.created,
      source: QrActivitySource.manual,
    );
  }

  @override
  void dispose() {
    _inboundImageShare.dispose();
    if (widget.historyController == null) {
      unawaited(_historyController?.then((controller) => controller.dispose()));
    }
    if (widget.customizationEntitlement == null) {
      unawaited(
        _customizationEntitlement.then((controller) => controller.dispose()),
      );
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
          if (service == null || !_inboundShareReady) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_selectedIndex) {
            0 => FutureBuilder<CustomizationEntitlement>(
              future: _customizationEntitlement,
              builder: (context, entitlementSnapshot) {
                final entitlement = entitlementSnapshot.data;
                return entitlement == null
                    ? const Center(child: CircularProgressIndicator())
                    : NavigatorPopHandler<void>(
                        onPopWithResult: (_) =>
                            _createNavigatorKey.currentState?.pop(),
                        child: Navigator(
                          key: _createNavigatorKey,
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => QrGenerationSpikePage(
                              secureQrService: service,
                              customizationEntitlement: entitlement,
                              customCenterImageStore: _customCenterImageStore,
                              onCreated: _recordCreated,
                              onSave: _saveCreated,
                              onBarcodeCreated: _recordBarcodeCreated,
                              onBarcodeSave: _saveBarcodeCreated,
                            ),
                          ),
                        ),
                      );
              },
            ),
            1 => QrScannerPage(
              key: ValueKey(_scanSession),
              secureQrService: service,
              onBatchRequested: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BatchSessionsPage(secureQrService: service),
                  ),
                );
              },
              onScanned: _recordScanned,
              startCamera: !_imageOnlyLaunch && _sharedImageError == null,
              imageError: _sharedImageError,
              sharedImagePath: _sharedImagePath,
              onSharedImageConsumed: _sharedImageConsumed,
            ),
            2 => FutureBuilder<HistoryController>(
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
                    : HistoryPage(
                        controller: controller,
                        customizationEntitlement: _customizationEntitlement,
                      );
              },
            ),
            _ => FutureBuilder<CustomizationEntitlement>(
              future: _customizationEntitlement,
              builder: (context, entitlementSnapshot) {
                final entitlement = entitlementSnapshot.data;
                return entitlement == null
                    ? const Center(child: CircularProgressIndicator())
                    : SettingsPage(
                        customizationEntitlement: entitlement,
                        customCenterImageStore: _customCenterImageStore,
                        packageInfo: _loadPackageInfo(),
                      );
              },
            ),
          };
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            _sharedImageError = null;
            _imageOnlyLaunch = false;
          }
          if (index == 1 && _selectedIndex == 1) {
            _scanSession += 1;
          }
          if (index == 0 && _selectedIndex != 0) {
            _createNavigatorKey.currentState?.popUntil(
              (route) => route.isFirst,
            );
          }
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Create'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class QrGenerationSpikePage extends StatefulWidget {
  const QrGenerationSpikePage({
    required this.secureQrService,
    required this.customizationEntitlement,
    this.customCenterImageStore,
    this.imagePicker,
    this.onCreated,
    this.onSave,
    this.onBarcodeCreated,
    this.onBarcodeSave,
    super.key,
  });

  final SecureQrService secureQrService;
  final CustomizationEntitlement customizationEntitlement;
  final CustomCenterImageStore? customCenterImageStore;
  final ImagePicker? imagePicker;
  final Future<void> Function(GeneratedBarcode)? onBarcodeCreated;
  final Future<void> Function(GeneratedBarcode)? onBarcodeSave;
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    required Uint8List qrPngBytes,
  })?
  onCreated;
  final Future<void> Function({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
  })?
  onSave;

  @override
  State<QrGenerationSpikePage> createState() => _QrGenerationSpikePageState();
}

class _QrGenerationSpikePageState extends State<QrGenerationSpikePage> {
  static const _policy = QrCreationPayloadPolicy();
  static const _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  static const _pngValidator = QrPngValidator();

  final _controller = TextEditingController(text: 'https://example.com/');
  late final ImagePicker _imagePicker;
  String? _error;
  Uint8List? _customImageBytes;
  var _decorationMode = QrCenterDecorationMode.daliIcon;
  bool _generating = false;
  bool _trialNoticeAcknowledged = false;
  bool _hasQrContent = true;
  ScannedCodeFormat _format = ScannedCodeFormat.qrCode;
  QrCreationType _contentType = QrCreationType.text;
  StructuredQrDraft _structuredDraft = const StructuredQrDraft(
    type: QrCreationType.contact,
  );
  bool get _wifiMode => _contentType == QrCreationType.wifi;
  bool get _structuredMode => _contentType != QrCreationType.text && !_wifiMode;
  WifiQrDraft _wifiDraft = const WifiQrDraft();

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _controller.addListener(_syncQrContentState);
    final storeBytes = widget.customCenterImageStore?.customImageBytes;
    if (storeBytes != null) {
      _customImageBytes = storeBytes;
      _decorationMode = QrCenterDecorationMode.customImage;
    }
    widget.customCenterImageStore?.addListener(_onStoreChanged);
    unawaited(_recoverLostImage());
  }

  void _onStoreChanged() {
    final storeBytes = widget.customCenterImageStore?.customImageBytes;
    if (storeBytes != null) {
      setState(() {
        _customImageBytes = storeBytes;
        _decorationMode = QrCenterDecorationMode.customImage;
      });
    } else if (_decorationMode == QrCenterDecorationMode.customImage) {
      setState(() {
        _customImageBytes = null;
        _decorationMode = QrCenterDecorationMode.daliIcon;
      });
    }
  }

  @override
  void dispose() {
    widget.customCenterImageStore?.removeListener(_onStoreChanged);
    _controller.removeListener(_syncQrContentState);
    _controller.dispose();
    super.dispose();
  }

  void _syncQrContentState() {
    final hasContent = _controller.text.isNotEmpty;
    if (hasContent == _hasQrContent) return;
    setState(() => _hasQrContent = hasContent);
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      final file = response.file;
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _customImageBytes = bytes;
        _decorationMode = QrCenterDecorationMode.customImage;
      });
    } on Object {
      // Image recovery is best-effort; users can select the image again.
    }
  }

  Future<void> _pickCustomImage() async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      final cropped = await ImageCropPage.crop(context, imageBytes: bytes);
      if (cropped == null || !mounted) return;
      setState(() {
        _customImageBytes = cropped;
        _decorationMode = QrCenterDecorationMode.customImage;
      });
      await widget.customCenterImageStore?.setImage(cropped);
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'The selected image could not be opened.');
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      if (_format != ScannedCodeFormat.qrCode ||
          _contentType != QrCreationType.text) {
        final entitlement = widget.customizationEntitlement;
        if (entitlement is TrialCustomizationEntitlement) {
          final trial = entitlement as TrialCustomizationEntitlement;
          if (trial.canStartTrial) await trial.startTrial();
          if (!mounted) return;
        }
        if (!_trialNoticeAcknowledged &&
            entitlement is TrialCustomizationEntitlement &&
            (entitlement as TrialCustomizationEntitlement).trialRemaining !=
                null) {
          final continued = await showCustomizationTrial(context, entitlement);
          if (!mounted || !continued) return;
          _trialNoticeAcknowledged = true;
        }
        if (!entitlement.isUnlocked) {
          await _showCreationUnlock();
          if (!mounted || !entitlement.isUnlocked) return;
        }
      }
      if (_format != ScannedCodeFormat.qrCode) {
        final code = await BarcodeGenerator.generate(_controller.text, _format);
        if (!mounted) return;
        await widget.onBarcodeCreated?.call(code);
        if (!mounted) return;
        setState(() => _error = null);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                GeneratedBarcodePage(code: code, onSave: widget.onBarcodeSave),
          ),
        );
        return;
      }
      final payload = _policy.validate(
        _wifiMode
            ? _wifiDraft.encode()
            : _structuredMode
            ? _structuredDraft.encode()
            : _controller.text,
      );
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
        case QrCenterDecorationMode.customImage:
          final bytes =
              _customImageBytes ??
              widget.customCenterImageStore?.customImageBytes;
          if (bytes == null) {
            throw const FormatException(
              'Choose an image for the center emblem.',
            );
          }
          decoration = QrCenterDecoration.customImage(bytes);
      }
      final png = _renderValidated(matrix, payload.value, decoration);
      if (!mounted) return;
      setState(() => _error = null);
      var recorded = false;
      if (_decorationMode != QrCenterDecorationMode.customImage ||
          widget.customizationEntitlement.isUnlocked) {
        if (widget.onCreated != null) {
          await widget.onCreated!(
            payload: payload.value,
            verificationCode: verification?.code,
            registrableDomain: verification is SecureQrResult
                ? verification.registrableDomain
                : null,
            qrPngBytes: png.bytes,
          );
          recorded = true;
        }
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => GeneratedQrPage(
            payload: payload,
            matrix: matrix,
            renderedQrBytes: png.bytes,
            verification: verification,
            decorationMode: _decorationMode,
            customizationEntitlement: widget.customizationEntitlement,
            initiallyRecorded: recorded,
            onCreated: widget.onCreated,
            onSave: widget.onSave,
          ),
        ),
      );
    } on QrCreationPayloadValidationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on QrPayloadTooLongException {
      if (mounted) {
        setState(
          () => _error =
              'This content is too large for a decorated Level H QR code.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Code generation failed. Check the content and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showCreationUnlock() async {
    final entitlement = widget.customizationEntitlement;
    final navigator = Navigator.of(context);
    var closed = false;
    void closeWhenUnlocked() {
      if (entitlement.isUnlocked && mounted && !closed) {
        closed = true;
        navigator.pop();
      }
    }

    entitlement.addListener(closeWhenUnlocked);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SingleChildScrollView(
          child: CustomizationUnlockSheet(
            entitlement: entitlement,
            title: 'Unlock more code types',
            description:
                'Create barcodes and QR codes for Wi-Fi, contacts, events, '
                'locations, email, phone, and SMS with your lifetime unlock. '
                'Custom logo exports and extended history are also included.',
          ),
        ),
      );
    } finally {
      closed = true;
      entitlement.removeListener(closeWhenUnlocked);
    }
  }

  RenderedQrPng _renderValidated(
    QrMatrix matrix,
    String payload,
    QrCenterDecoration? decoration,
  ) {
    if (decoration == null) return _pngRenderer.render(matrix);
    for (final coverage in const [0.20, 0.18, 0.16, 0.14]) {
      final rendered = _pngRenderer.render(
        matrix,
        centerDecoration: decoration,
        centerCoverage: coverage,
      );
      if (_pngValidator.containsExactPayload(rendered.bytes, payload)) {
        return rendered;
      }
    }
    throw const FormatException(
      'This center image cannot be used reliably with this content.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.customizationEntitlement,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            _format == ScannedCodeFormat.qrCode
                ? 'Create QR code'
                : 'Create ${_format.label}',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<ScannedCodeFormat>(
                initialValue: _format,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Code format',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final format in BarcodeGenerator.formats)
                    DropdownMenuItem(value: format, child: Text(format.label)),
                ],
                onChanged: _generating
                    ? null
                    : (format) {
                        if (format != null && format != _format) {
                          setState(() {
                            _format = format;
                            _contentType = QrCreationType.text;
                            _wifiDraft = const WifiQrDraft();
                            _error = null;
                          });
                        }
                      },
              ),
              const SizedBox(height: 16),
              if (!widget.customizationEntitlement.isUnlocked &&
                  (_format != ScannedCodeFormat.qrCode ||
                      _contentType != QrCreationType.text)) ...[
                Text(
                  widget.customizationEntitlement
                              is TrialCustomizationEntitlement &&
                          (widget.customizationEntitlement
                                  as TrialCustomizationEntitlement)
                              .canStartTrial
                      ? 'This code type includes a free one-month trial. Your trial starts when you generate it.'
                      : 'This code type is included with the lifetime unlock. You can fill in the details before unlocking.',
                ),
                const SizedBox(height: 16),
              ],
              if (_format == ScannedCodeFormat.qrCode) ...[
                DropdownButtonFormField<QrCreationType>(
                  key: ValueKey(_format),
                  initialValue: _contentType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'QR content type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in QrCreationType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _generating
                      ? null
                      : (value) {
                          if (value == null || value == _contentType) return;
                          setState(() {
                            _contentType = value;
                            _structuredDraft = StructuredQrDraft(type: value);
                            _wifiDraft = const WifiQrDraft();
                            _error = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
              ],
              if (_wifiMode) ...[
                WifiQrFields(
                  onChanged: (draft) => setState(() {
                    _wifiDraft = draft;
                    _error = null;
                  }),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ] else if (_structuredMode) ...[
                StructuredQrFields(
                  key: ValueKey(_contentType),
                  type: _contentType,
                  enabled: !_generating,
                  onChanged: (draft) => setState(() {
                    _structuredDraft = draft;
                    _error = null;
                  }),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ] else
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: _format == ScannedCodeFormat.qrCode
                        ? 'QR content'
                        : 'Code content',
                    helperText: _format == ScannedCodeFormat.qrCode
                        ? null
                        : BarcodeGenerator.help(_format),
                    helperMaxLines: 4,
                    errorMaxLines: 4,
                    errorText: _error,
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasQrContent
                        ? IconButton(
                            tooltip: _format == ScannedCodeFormat.qrCode
                                ? 'Clear QR content'
                                : 'Clear code content',
                            onPressed: () {
                              _controller.clear();
                              setState(() => _error = null);
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => _generate(),
                ),
              const SizedBox(height: 12),
              if (_format == ScannedCodeFormat.qrCode)
                SegmentedButton<QrCenterDecorationMode>(
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: QrCenterDecorationMode.none,
                      label: Text('Plain'),
                    ),
                    ButtonSegment(
                      value: QrCenterDecorationMode.verificationCode,
                      label: Text('Code'),
                    ),
                    ButtonSegment(
                      value: QrCenterDecorationMode.daliIcon,
                      label: Text('Dali'),
                    ),
                    ButtonSegment(
                      value: QrCenterDecorationMode.customImage,
                      label: Text('Custom'),
                    ),
                  ],
                  selected: {_decorationMode},
                  onSelectionChanged: (selection) {
                    final selected = selection.single;
                    if (selected == QrCenterDecorationMode.customImage &&
                        _customImageBytes == null) {
                      unawaited(_pickCustomImage());
                      return;
                    }
                    setState(() {
                      _decorationMode = selected;
                    });
                  },
                ),
              if (_format == ScannedCodeFormat.qrCode &&
                  _decorationMode == QrCenterDecorationMode.customImage) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_customImageBytes case final bytes?)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          bytes,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.customizationEntitlement.isUnlocked
                            ? 'Custom export unlocked'
                            : 'Custom preview',
                      ),
                    ),
                    if (_customImageBytes case final bytes?) ...[
                      TextButton.icon(
                        onPressed: () async {
                          final cropped = await ImageCropPage.crop(
                            context,
                            imageBytes: bytes,
                          );
                          if (cropped == null || !mounted) return;
                          setState(() => _customImageBytes = cropped);
                          await widget.customCenterImageStore?.setImage(
                            cropped,
                          );
                        },
                        icon: const Icon(Icons.crop),
                        label: const Text('Crop'),
                      ),
                    ],
                    TextButton.icon(
                      onPressed: _pickCustomImage,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    (_wifiMode
                            ? _wifiDraft.ssid.isEmpty
                            : _structuredMode
                            ? false
                            : !_hasQrContent) ||
                        _generating
                    ? null
                    : () => unawaited(_generate()),
                child: Text(
                  _generating
                      ? 'Generating...'
                      : _format == ScannedCodeFormat.qrCode
                      ? 'Generate QR code'
                      : 'Generate ${_format.label}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.customizationEntitlement,
    required this.packageInfo,
    this.customCenterImageStore,
    this.imagePicker,
    this.hiddenUnlockEnabled = testFlightUnlockEnabled,
    super.key,
  });

  final CustomizationEntitlement customizationEntitlement;
  final Future<PackageInfo> packageInfo;
  final CustomCenterImageStore? customCenterImageStore;
  final ImagePicker? imagePicker;
  final bool hiddenUnlockEnabled;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _packageTapCount = 0;

  Future<void> _handlePackageTap() async {
    final entitlement = widget.customizationEntitlement;
    if (entitlement.isUnlocked ||
        entitlement is! HiddenCustomizationEntitlement) {
      return;
    }
    _packageTapCount += 1;
    if (_packageTapCount < 5) return;
    _packageTapCount = 0;
    await (entitlement as HiddenCustomizationEntitlement).unlockFromAbout();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Lifetime customization unlocked.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.customizationEntitlement,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Customization',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _CustomizationStatus(
                entitlement: widget.customizationEntitlement,
              ),
              const SizedBox(height: 16),
              _CustomizationPurchaseControls(
                entitlement: widget.customizationEntitlement,
              ),
              if (widget.customCenterImageStore != null) ...[
                const SizedBox(height: 24),
                _QrCenterImageSettings(
                  store: widget.customCenterImageStore!,
                  imagePicker: widget.imagePicker ?? ImagePicker(),
                ),
              ],
              const SizedBox(height: 32),
              Text('About', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<PackageInfo>(
                future: widget.packageInfo,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Column(
                    children: [
                      _SettingsRow(
                        label: 'Name',
                        value: info?.appName ?? 'Dali QR',
                      ),
                      _SettingsRow(
                        label: 'Version',
                        value: info == null
                            ? 'Loading...'
                            : '${info.version} (${info.buildNumber})',
                      ),
                      _SettingsRow(
                        label: 'Package',
                        value: info?.packageName ?? 'com.dalifin.qr',
                        onTap: widget.hiddenUnlockEnabled
                            ? () => unawaited(_handlePackageTap())
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomizationStatus extends StatelessWidget {
  const _CustomizationStatus({required this.entitlement});

  final CustomizationEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unlocked = entitlement.isUnlocked;
    final trial = entitlement is TrialCustomizationEntitlement
        ? (entitlement as TrialCustomizationEntitlement).trialRemaining
        : null;
    final trialAvailable =
        entitlement is TrialCustomizationEntitlement &&
        (entitlement as TrialCustomizationEntitlement).canStartTrial;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    unlocked
                        ? Icons.workspace_premium_outlined
                        : Icons.lock_outline,
                    color: unlocked
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dali QR Custom',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        unlocked
                            ? Icons.check_circle_outline
                            : Icons.lock_outline,
                        size: 16,
                        color: unlocked
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trial != null
                            ? 'Trial'
                            : unlocked
                            ? 'Unlocked'
                            : 'Locked',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: unlocked
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              trial != null
                  ? 'Free trial: ${trialCountdown(trial)}. Unlock once to keep your benefits.'
                  : trialAvailable
                  ? 'Try the creation benefits free for one month when you first use them.'
                  : unlocked
                  ? 'Your lifetime creation and customization features are ready to use.'
                  : 'Unlock once for more code types, personalized QR codes, and extended history.',
            ),
            const SizedBox(height: 20),
            Text('Benefits', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const _CustomizationBenefit(
              icon: Icons.qr_code_2,
              text:
                  'Create Wi-Fi, contact, event, location, email, phone, and SMS QR codes',
            ),
            const SizedBox(height: 10),
            const _CustomizationBenefit(
              icon: Icons.view_week_outlined,
              text: 'Create barcodes in all supported formats',
            ),
            const SizedBox(height: 10),
            const _CustomizationBenefit(
              icon: Icons.add_photo_alternate_outlined,
              text: 'Add your own image or logo to QR codes',
            ),
            const SizedBox(height: 10),
            const _CustomizationBenefit(
              icon: Icons.ios_share_outlined,
              text: 'Save, copy, and share your personalized QR codes',
            ),
            const SizedBox(height: 10),
            const _CustomizationBenefit(
              icon: Icons.history_outlined,
              text: 'Keep and access your QR history for longer than one week',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomizationBenefit extends StatelessWidget {
  const _CustomizationBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CustomizationPurchaseControls extends StatelessWidget {
  const _CustomizationPurchaseControls({required this.entitlement});

  final CustomizationEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final lifetimeOwned = entitlement is TrialCustomizationEntitlement
        ? (entitlement as TrialCustomizationEntitlement).hasLifetimeAccess
        : entitlement.isUnlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entitlement.message case final message?) ...[
          Text(message),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: lifetimeOwned || entitlement.isBusy
              ? null
              : () => unawaited(
                  entitlement.price == null
                      ? entitlement.refresh()
                      : entitlement.purchase(),
                ),
          icon: entitlement.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  lifetimeOwned
                      ? Icons.check_circle_outline
                      : Icons.lock_open_outlined,
                ),
          label: Text(
            lifetimeOwned
                ? 'Lifetime customization unlocked'
                : entitlement.price == null
                ? 'Check unlock availability'
                : 'Unlock for ${entitlement.price}',
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: entitlement.isBusy || !entitlement.isStoreAvailable
              ? null
              : () => unawaited(entitlement.restore()),
          icon: const Icon(Icons.restore_outlined),
          label: const Text('Restore purchases'),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: onTap == null ? SelectableText(value) : Text(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCenterImageSettings extends StatelessWidget {
  const _QrCenterImageSettings({
    required this.store,
    required this.imagePicker,
  });

  final CustomCenterImageStore store;
  final ImagePicker imagePicker;

  Future<void> _pickImage(BuildContext context) async {
    try {
      final selected = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (!context.mounted) return;
      final cropped = await ImageCropPage.crop(context, imageBytes: bytes);
      if (cropped == null || !context.mounted) return;
      await store.setImage(cropped);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom center image updated.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load the selected image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bytes = store.customImageBytes;
        final hasImage = bytes != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Center Image',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: colorScheme.surfaceContainerHighest,
                            child: hasImage
                                ? Image.memory(
                                    bytes,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Image.asset(
                                      'assets/dali_smart_code_icon.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Default Dali center icon',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasImage
                                    ? 'Custom image active'
                                    : 'Default Dali icon',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasImage
                                    ? 'Used as the center emblem when generating QR codes.'
                                    : 'Add an image to display at the center of generated QR codes.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(context),
                          icon: Icon(
                            hasImage
                                ? Icons.edit_outlined
                                : Icons.add_photo_alternate_outlined,
                          ),
                          label: Text(
                            hasImage ? 'Change image' : 'Choose image',
                          ),
                        ),
                        if (hasImage) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final cropped = await ImageCropPage.crop(
                                context,
                                imageBytes: bytes,
                              );
                              if (cropped == null || !context.mounted) return;
                              await store.setImage(cropped);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Custom center image updated.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.crop),
                            label: const Text('Crop'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await store.clearImage();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Custom center image removed.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
