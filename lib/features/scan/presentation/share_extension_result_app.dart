import '../domain/qr_payload_classifier.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../secure_qr/application/secure_qr_loader.dart';
import '../../secure_qr/domain/secure_qr_service.dart';
import '../domain/scanned_code.dart';
import '../data/offline_image_decoder.dart';
import 'qr_scanner_page.dart';

const _shareExtensionChannel = MethodChannel('dali_qr/share_extension');

void runDaliQrShareExtension() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(DaliQrShareExtensionApp(codes: _codesFromRoute(route)));
}

List<ScannedCode> _codesFromRoute(String route) {
  try {
    final encoded = Uri.parse(route).queryParameters['data'];
    if (encoded == null || encoded.isEmpty) return const [];
    final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
    final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
    if (decoded is! List<Object?>) return const [];
    return [
      for (final item in decoded)
        if (item case {
          'value': final String value,
          'format': final String format,
        })
          ScannedCode(
            value: value,
            format: ScannedCodeFormat.fromStorageKey(format),
            source: ScanSource.sharedImage,
          ),
    ];
  } on Object {
    return const [];
  }
}

final class DaliQrShareExtensionApp extends StatelessWidget {
  const DaliQrShareExtensionApp({
    required this.codes,
    this.secureQrService,
    this.imageFallback,
    super.key,
  });

  final List<ScannedCode> codes;
  final Future<List<ScannedCode>> Function()? imageFallback;

  /// Optional preloaded service; otherwise uses the locally bundled suffix list.
  final SecureQrService? secureQrService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dali QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315caa)),
        useMaterial3: true,
      ),
      home: secureQrService != null
          ? _ShareResultPage(
              codes: codes,
              secureQrService: secureQrService!,
              imageFallback: imageFallback,
            )
          : FutureBuilder<SecureQrService>(
              future: SecureQrLoader.load(),
              builder: (context, snapshot) {
                final service = snapshot.data;
                if (service == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return _ShareResultPage(
                  codes: codes,
                  secureQrService: service,
                  imageFallback: imageFallback,
                );
              },
            ),
    );
  }
}

final class _ShareResultPage extends StatefulWidget {
  const _ShareResultPage({
    required this.codes,
    required this.secureQrService,
    this.imageFallback,
  });
  final Future<List<ScannedCode>> Function()? imageFallback;

  final List<ScannedCode> codes;
  final SecureQrService secureQrService;

  @override
  State<_ShareResultPage> createState() => _ShareResultPageState();
}

class _ShareResultPageState extends State<_ShareResultPage> {
  ScannedCode? _selectedCode;
  late List<ScannedCode> _codes;
  bool _readingFallback = false;

  @override
  void initState() {
    super.initState();
    _codes = widget.codes;
    if (_codes.length == 1) _selectedCode = _codes.single;
    if (_codes.isEmpty) {
      _readingFallback = true;
      unawaited(_loadFallback());
    }
  }

  Future<void> _loadFallback() async {
    List<ScannedCode> codes = const [];
    try {
      if (widget.imageFallback case final read?) {
        codes = await read();
      } else {
        final bytes = await _shareExtensionChannel.invokeMethod<Uint8List>(
          'readFallbackImage',
        );
        if (bytes != null) {
          codes = await const OfflineImageDecoder().decodeBytes(
            bytes,
            source: ScanSource.sharedImage,
          );
        }
      }
    } on Object {
      // Read-only extension must remain dismissible if fallback is unavailable.
    }
    if (mounted) {
      setState(() {
        _codes = orderScannedCodes(codes);
        _selectedCode = _codes.length == 1 ? _codes.single : null;
        _readingFallback = false;
      });
    }
  }

  Future<void> _finish() => _shareExtensionChannel.invokeMethod<void>('finish');

  @override
  Widget build(BuildContext context) {
    final selectedCode = _selectedCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code or barcode'),
        actions: [
          IconButton(
            onPressed: _finish,
            tooltip: 'Done',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: _readingFallback
          ? const Center(child: CircularProgressIndicator())
          : _codes.isEmpty
          ? _EmptyResult(onDone: _finish)
          : selectedCode == null
          ? _ResultSelection(
              codes: _codes,
              onSelected: (code) => setState(() => _selectedCode = code),
              onDone: _finish,
            )
          : ScannedCodeResultView(
              code: selectedCode,
              secureQrService: widget.secureQrService,
              allowRouting: false,
              scanAgainLabel: _codes.length > 1
                  ? 'Choose another result'
                  : 'Done',
              onScanAgain: _codes.length > 1
                  ? () => setState(() => _selectedCode = null)
                  : _finish,
            ),
    );
  }
}

final class _ResultSelection extends StatelessWidget {
  const _ResultSelection({
    required this.codes,
    required this.onSelected,
    required this.onDone,
  });

  final List<ScannedCode> codes;
  final ValueChanged<ScannedCode> onSelected;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
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
          for (final code in codes)
            Card(
              child: ListTile(
                leading: const Icon(Icons.barcode_reader),
                title: Text(code.format.label),
                subtitle: Text(
                  const QrPayloadClassifier().classify(code.value).previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(code),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.close),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

final class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No readable QR code or supported barcode was found in that image.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onDone, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}
