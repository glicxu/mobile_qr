import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../scan/domain/qr_payload_classifier.dart';
import '../../scan/domain/scanned_code.dart';
import '../application/barcode_generator.dart';
import '../application/qr_share.dart';

class GeneratedBarcodePage extends StatefulWidget {
  const GeneratedBarcodePage({required this.code, this.onSave, super.key});
  final GeneratedBarcode code;
  final Future<void> Function(GeneratedBarcode)? onSave;
  @override
  State<GeneratedBarcodePage> createState() => _GeneratedBarcodePageState();
}

class _GeneratedBarcodePageState extends State<GeneratedBarcodePage> {
  bool _busy = false;
  bool _saved = false;

  Future<void> _act(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The action could not be completed. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final canSave =
        widget.onSave != null &&
        !const QrPayloadClassifier().classify(code.value).isEphemeral;
    return Scaffold(
      appBar: AppBar(title: Text(code.format.label)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          children: [
            TextFormField(
              initialValue: code.value,
              readOnly: true,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Code content',
                border: OutlineInputBorder(),
              ),
              // The immutable generated value remains independent of the editor.
              key: ValueKey(code.value),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: '${code.format.label} image',
              image: true,
              child: InteractiveViewer(
                child: Image.memory(
                  code.png,
                  filterQuality: FilterQuality.none,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if ([
              ScannedCodeFormat.upcA,
              ScannedCodeFormat.upcE,
              ScannedCodeFormat.ean8,
              ScannedCodeFormat.ean13,
              ScannedCodeFormat.itf14,
            ].contains(code.format))
              const Text(
                'Use an identifier assigned to your product. A valid barcode does not register or identify a product.',
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => Clipboard.setData(
                            ClipboardData(text: code.value),
                          ),
                          'Contents copied.',
                        ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy contents'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(() async {
                          await const MethodChannel(
                            'dali_qr/clipboard',
                          ).invokeMethod<void>('copyPng', {
                            'bytes': code.png,
                            'payload': code.value,
                          });
                        }, 'Code image copied.'),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Copy image'),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(() async {
                          final box = context.findRenderObject() as RenderBox?;
                          final origin = box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size;
                          await QrShare.sharePng(
                            bytes: code.png,
                            fileName:
                                'dali-${code.format.storageKey}-${DateTime.now().microsecondsSinceEpoch}.png',
                            sharePositionOrigin: origin,
                          );
                        }, 'Code ready to share.'),
                  icon: const Icon(Icons.share),
                  label: const Text('Share image'),
                ),
                if (canSave)
                  OutlinedButton.icon(
                    onPressed: _busy || _saved
                        ? null
                        : () => _act(() async {
                            await widget.onSave!(code);
                            if (mounted) setState(() => _saved = true);
                          }, 'Code saved.'),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(_saved ? 'Saved' : 'Save to Saved'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Recreates a previously generated barcode in its original symbology.
class StoredBarcodeButton extends StatefulWidget {
  const StoredBarcodeButton({
    required this.value,
    required this.format,
    super.key,
  });
  final String value;
  final ScannedCodeFormat format;
  @override
  State<StoredBarcodeButton> createState() => _StoredBarcodeButtonState();
}

class _StoredBarcodeButtonState extends State<StoredBarcodeButton> {
  bool _preparing = false;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.view_week_outlined),
    label: Text(_preparing ? 'Preparing...' : 'View barcode'),
    onPressed: _preparing
        ? null
        : () async {
            setState(() => _preparing = true);
            try {
              final code = await BarcodeGenerator.generate(
                widget.value,
                widget.format,
              );
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GeneratedBarcodePage(code: code),
                ),
              );
            } on Object {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This barcode could not be recreated.'),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _preparing = false);
            }
          },
  );
}
