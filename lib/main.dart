import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'features/create/application/qr_encoder.dart';
import 'features/create/application/qr_png_validator.dart';
import 'features/create/application/qr_share.dart';
import 'features/create/data/dart_qr_encoder.dart';
import 'features/create/data/qr_png_renderer.dart';
import 'features/create/domain/qr_center_decoration.dart';
import 'features/create/domain/qr_creation_payload_policy.dart';
import 'features/create/domain/qr_matrix.dart';
import 'features/history/application/qr_clipboard.dart';
import 'features/history/application/history_controller.dart';
import 'features/history/domain/qr_history.dart';
import 'features/history/presentation/history_page.dart';
import 'features/history/presentation/saved_page.dart';
import 'features/monetization/application/customization_entitlement.dart';
import 'features/scan/application/inbound_image_share.dart';
import 'features/scan/presentation/qr_scanner_page.dart';
import 'features/secure_qr/application/secure_qr_loader.dart';
import 'features/secure_qr/domain/secure_qr_service.dart';

void main() => runApp(const DaliQrApp());

class DaliQrApp extends StatelessWidget {
  const DaliQrApp({
    this.secureQrService,
    this.historyController,
    this.customizationEntitlement,
    this.inboundImageShare,
    super.key,
  });

  final SecureQrService? secureQrService;
  final HistoryController? historyController;
  final CustomizationEntitlement? customizationEntitlement;
  final InboundImageShareSource? inboundImageShare;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dali Secure QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315caa)),
        useMaterial3: true,
      ),
      home: DaliQrHome(
        secureQrService: secureQrService,
        historyController: historyController,
        customizationEntitlement: customizationEntitlement,
        inboundImageShare: inboundImageShare,
      ),
    );
  }
}

class DaliQrHome extends StatefulWidget {
  const DaliQrHome({
    this.secureQrService,
    this.historyController,
    this.customizationEntitlement,
    this.inboundImageShare,
    super.key,
  });

  final SecureQrService? secureQrService;
  final HistoryController? historyController;
  final CustomizationEntitlement? customizationEntitlement;
  final InboundImageShareSource? inboundImageShare;

  @override
  State<DaliQrHome> createState() => _DaliQrHomeState();
}

class _DaliQrHomeState extends State<DaliQrHome> {
  int _selectedIndex = 0;
  late final Future<SecureQrService> _secureQrService;
  Future<HistoryController>? _historyController;
  late final Future<CustomizationEntitlement> _customizationEntitlement;
  Future<PackageInfo>? _packageInfo;
  late final InboundImageShareSource _inboundImageShare;
  String? _sharedImagePath;

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
    final suppliedEntitlement = widget.customizationEntitlement;
    _customizationEntitlement = suppliedEntitlement == null
        ? StoreCustomizationEntitlement.open()
        : Future.value(suppliedEntitlement);
    _inboundImageShare = widget.inboundImageShare ?? InboundImageShare();
    unawaited(_inboundImageShare.start(_receiveSharedImage));
  }

  void _receiveSharedImage(String path) {
    if (!mounted) return;
    setState(() {
      _sharedImagePath = path;
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

  Future<void> _saveScanned({
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
      activityKind: QrActivityKind.scanned,
      source: QrActivitySource.camera,
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
          if (service == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_selectedIndex) {
            0 => FutureBuilder<CustomizationEntitlement>(
              future: _customizationEntitlement,
              builder: (context, entitlementSnapshot) {
                final entitlement = entitlementSnapshot.data;
                return entitlement == null
                    ? const Center(child: CircularProgressIndicator())
                    : QrGenerationSpikePage(
                        secureQrService: service,
                        customizationEntitlement: entitlement,
                        onCreated: _recordCreated,
                        onSave: _saveCreated,
                      );
              },
            ),
            1 => QrScannerPage(
              secureQrService: service,
              onScanned: _recordScanned,
              onSave: _saveScanned,
              sharedImagePath: _sharedImagePath,
              onSharedImageConsumed: _sharedImageConsumed,
            ),
            2 => FutureBuilder<HistoryController>(
              future: _loadHistory(),
              builder: (context, historySnapshot) {
                final controller = historySnapshot.data;
                if (historySnapshot.hasError) {
                  return const Center(
                    child: Text('Saved QRs could not be loaded.'),
                  );
                }
                return controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : SavedPage(controller: controller);
              },
            ),
            3 => FutureBuilder<HistoryController>(
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
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Create'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Saved',
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
    this.imagePicker,
    this.onCreated,
    this.onSave,
    super.key,
  });

  final SecureQrService secureQrService;
  final CustomizationEntitlement customizationEntitlement;
  final ImagePicker? imagePicker;
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
  QrCreationPayload? _payload;
  QrMatrix? _matrix;
  QrVerificationResult? _verification;
  Uint8List? _renderedQrBytes;
  String? _error;
  Uint8List? _customImageBytes;
  var _decorationMode = QrCenterDecorationMode.daliIcon;
  bool _generating = false;
  bool _exporting = false;
  bool _recordedCurrentQr = false;
  bool _savedCurrentQr = false;
  bool _savingCurrentQr = false;
  bool _hasQrContent = true;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _controller.addListener(_syncQrContentState);
    unawaited(_recoverLostImage());
  }

  @override
  void dispose() {
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
      setState(() {
        _customImageBytes = bytes;
        _decorationMode = QrCenterDecorationMode.customImage;
        _clearGeneratedOutput();
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'The selected image could not be opened.');
    }
  }

  void _clearGeneratedOutput() {
    _payload = null;
    _matrix = null;
    _verification = null;
    _renderedQrBytes = null;
    _recordedCurrentQr = false;
    _savedCurrentQr = false;
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
        case QrCenterDecorationMode.customImage:
          final bytes = _customImageBytes;
          if (bytes == null) {
            throw const FormatException(
              'Choose an image for the center emblem.',
            );
          }
          decoration = QrCenterDecoration.customImage(bytes);
      }
      final png = _renderValidated(matrix, payload.value, decoration);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _matrix = matrix;
        _verification = verification;
        _renderedQrBytes = png.bytes;
        _error = null;
        _recordedCurrentQr = false;
        _savedCurrentQr = false;
      });
      if (_decorationMode != QrCenterDecorationMode.customImage ||
          widget.customizationEntitlement.isUnlocked) {
        await _recordCurrentQr();
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

  Future<void> _recordCurrentQr() async {
    final onCreated = widget.onCreated;
    final payload = _payload;
    final pngBytes = _renderedQrBytes;
    if (_recordedCurrentQr ||
        onCreated == null ||
        payload == null ||
        pngBytes == null) {
      return;
    }
    final verification = _verification;
    await onCreated(
      payload: payload.value,
      verificationCode: verification?.code,
      registrableDomain: verification is SecureQrResult
          ? verification.registrableDomain
          : null,
      qrPngBytes: pngBytes,
    );
    if (mounted) _recordedCurrentQr = true;
  }

  Future<void> _copyVerificationCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Verification code copied.')));
  }

  Future<void> _saveCurrentQr() async {
    final onSave = widget.onSave;
    final payload = _payload;
    final bytes = _renderedQrBytes;
    if (onSave == null ||
        payload == null ||
        bytes == null ||
        _savedCurrentQr ||
        _savingCurrentQr) {
      return;
    }
    setState(() => _savingCurrentQr = true);
    try {
      if (!await _ensureExportAllowed()) return;
      final verification = _verification;
      await onSave(
        payload: payload.value,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: bytes,
      );
      if (!mounted) return;
      setState(() => _savedCurrentQr = true);
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
      if (mounted) setState(() => _savingCurrentQr = false);
    }
  }

  Future<bool> _ensureExportAllowed() async {
    if (_decorationMode != QrCenterDecorationMode.customImage ||
        widget.customizationEntitlement.isUnlocked) {
      return true;
    }
    final entitlement = widget.customizationEntitlement;
    void closeWhenUnlocked() {
      if (entitlement.isUnlocked && mounted) {
        Navigator.of(context).pop(true);
      }
    }

    entitlement.addListener(closeWhenUnlocked);
    try {
      return await showModalBottomSheet<bool>(
            context: context,
            showDragHandle: true,
            builder: (context) =>
                _CustomizationUnlockSheet(entitlement: entitlement),
          ) ??
          false;
    } finally {
      entitlement.removeListener(closeWhenUnlocked);
    }
  }

  Future<void> _export({required bool copy}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (!await _ensureExportAllowed()) return;
      final payload = _payload;
      final pngBytes = _renderedQrBytes;
      if (payload == null || pngBytes == null) return;
      if (!_pngValidator.containsExactPayload(pngBytes, payload.value)) {
        throw const FormatException(
          'The QR could not be validated. Generate it again before exporting.',
        );
      }
      await _recordCurrentQr();
      if (!mounted) return;
      if (copy) {
        await QrClipboard.copyPng(bytes: pngBytes, payload: payload.value);
      } else {
        final renderBox = context.findRenderObject() as RenderBox?;
        final shareOrigin = renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size;
        await QrShare.sharePng(
          bytes: pngBytes,
          payload: payload.value,
          sharePositionOrigin: shareOrigin,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy ? 'QR copied.' : 'QR ready to share.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : 'The QR could not be exported.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _matrix;
    final payload = _payload;
    final renderedQrBytes = _renderedQrBytes;
    return ListenableBuilder(
      listenable: widget.customizationEntitlement,
      builder: (context, _) => Scaffold(
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
                  suffixIcon: _hasQrContent
                      ? IconButton(
                          tooltip: 'Clear QR content',
                          onPressed: () {
                            _controller.clear();
                            setState(_clearGeneratedOutput);
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                onSubmitted: (_) => _generate(),
              ),
              const SizedBox(height: 12),
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
                    _clearGeneratedOutput();
                  });
                },
              ),
              if (_decorationMode == QrCenterDecorationMode.customImage) ...[
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        verification.code,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () =>
                            unawaited(_copyVerificationCode(verification.code)),
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: 'Copy verification code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verification is SecureQrResult
                        ? 'Secure QR - ${verification.registrableDomain}'
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
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => unawaited(_export(copy: true)),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy QR image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _savingCurrentQr || _savedCurrentQr
                          ? null
                          : () => unawaited(_saveCurrentQr()),
                      icon: Icon(
                        _savedCurrentQr
                            ? Icons.bookmark_added
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        _savingCurrentQr
                            ? 'Saving...'
                            : _savedCurrentQr
                            ? 'Saved'
                            : 'Save QR',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _exporting
                          ? null
                          : () => unawaited(_export(copy: false)),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share QR image'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(payload.value),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.customizationEntitlement,
    required this.packageInfo,
    super.key,
  });

  final CustomizationEntitlement customizationEntitlement;
  final Future<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: customizationEntitlement,
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
              _CustomizationStatus(entitlement: customizationEntitlement),
              const SizedBox(height: 16),
              _CustomizationPurchaseControls(
                entitlement: customizationEntitlement,
                showRefresh: true,
              ),
              const SizedBox(height: 32),
              Text('App', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FutureBuilder<PackageInfo>(
                future: packageInfo,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Column(
                    children: [
                      _SettingsRow(
                        label: 'Name',
                        value: info?.appName ?? 'Dali Secure QR',
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unlocked ? Icons.lock_open_outlined : Icons.lock_outline,
              color: unlocked
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unlocked
                        ? 'Custom export unlocked'
                        : 'Custom export locked',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? 'Custom-logo QR export and saving are available.'
                        : 'Preview custom-logo QR codes for free. Purchase once to save, copy, or share them.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomizationPurchaseControls extends StatelessWidget {
  const _CustomizationPurchaseControls({
    required this.entitlement,
    this.showRefresh = false,
  });

  final CustomizationEntitlement entitlement;
  final bool showRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entitlement.message case final message?) ...[
          Text(message),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: entitlement.isUnlocked || entitlement.isBusy
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
                  entitlement.isUnlocked
                      ? Icons.check_circle_outline
                      : Icons.lock_open_outlined,
                ),
          label: Text(
            entitlement.isUnlocked
                ? 'Unlocked'
                : entitlement.price == null
                ? 'Lifetime unlock'
                : 'Unlock for ${entitlement.price}',
          ),
        ),
        TextButton(
          onPressed: entitlement.isBusy || !entitlement.isStoreAvailable
              ? null
              : () => unawaited(entitlement.restore()),
          child: const Text('Restore purchase'),
        ),
        if (showRefresh)
          TextButton.icon(
            onPressed: entitlement.isBusy
                ? null
                : () => unawaited(entitlement.refresh()),
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Check store'),
          ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _CustomizationUnlockSheet extends StatelessWidget {
  const _CustomizationUnlockSheet({required this.entitlement});

  final CustomizationEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: entitlement,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Custom QR lifetime',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Export QR codes with your own image or logo using a one-time purchase.',
              ),
              if (entitlement.message case final message?) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
              const SizedBox(height: 20),
              _CustomizationPurchaseControls(entitlement: entitlement),
              if (kDebugMode && entitlement is DebugCustomizationEntitlement)
                TextButton.icon(
                  onPressed: entitlement.isBusy
                      ? null
                      : () => unawaited(
                          (entitlement as DebugCustomizationEntitlement)
                              .unlockForTesting(),
                        ),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Unlock for testing'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
