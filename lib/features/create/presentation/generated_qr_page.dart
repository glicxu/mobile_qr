import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/monetization/application/customization_entitlement.dart';
import '../../../features/secure_qr/domain/secure_qr_service.dart';
import '../application/qr_png_validator.dart';
import '../application/qr_share.dart';
import '../domain/qr_center_decoration.dart';
import '../domain/qr_creation_payload_policy.dart';
import '../domain/qr_matrix.dart';

class GeneratedQrPage extends StatefulWidget {
  const GeneratedQrPage({
    required this.payload,
    required this.matrix,
    required this.renderedQrBytes,
    required this.verification,
    required this.decorationMode,
    required this.customizationEntitlement,
    this.initiallyRecorded = false,
    this.onCreated,
    this.onSave,
    super.key,
  });

  final QrCreationPayload payload;
  final QrMatrix matrix;
  final Uint8List renderedQrBytes;
  final QrVerificationResult? verification;
  final QrCenterDecorationMode decorationMode;
  final CustomizationEntitlement customizationEntitlement;
  final bool initiallyRecorded;
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
  State<GeneratedQrPage> createState() => _GeneratedQrPageState();
}

class _GeneratedQrPageState extends State<GeneratedQrPage> {
  static const _pngValidator = QrPngValidator();

  late final TextEditingController _contentController;
  late bool _recorded;
  bool _saved = false;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.payload.value);
    _recorded = widget.initiallyRecorded;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _recordCurrentQr() async {
    final onCreated = widget.onCreated;
    if (_recorded || onCreated == null) return;
    final verification = widget.verification;
    await onCreated(
      payload: widget.payload.value,
      verificationCode: verification?.code,
      registrableDomain: verification is SecureQrResult
          ? verification.registrableDomain
          : null,
      qrPngBytes: widget.renderedQrBytes,
    );
    if (mounted) _recorded = true;
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
    if (onSave == null || _saved || _saving) return;
    setState(() => _saving = true);
    try {
      final verification = widget.verification;
      await onSave(
        payload: widget.payload.value,
        verificationCode: verification?.code,
        registrableDomain: verification is SecureQrResult
            ? verification.registrableDomain
            : null,
        qrPngBytes: widget.renderedQrBytes,
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

  Future<bool> _ensureExportAllowed() async {
    if (widget.decorationMode != QrCenterDecorationMode.customImage ||
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
                CustomizationUnlockSheet(entitlement: entitlement),
          ) ??
          false;
    } finally {
      entitlement.removeListener(closeWhenUnlocked);
    }
  }

  Future<void> _shareQrImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (!await _ensureExportAllowed()) return;
      final payload = widget.payload;
      final pngBytes = widget.renderedQrBytes;
      if (!_pngValidator.containsExactPayload(pngBytes, payload.value)) {
        throw const FormatException(
          'The QR could not be validated. Generate it again before exporting.',
        );
      }
      await _recordCurrentQr();
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await QrShare.sharePng(
        bytes: pngBytes,
        payload: payload.value,
        sharePositionOrigin: shareOrigin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR ready to share.')));
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
    final verification = widget.verification;
    return ListenableBuilder(
      listenable: widget.customizationEntitlement,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('QR code')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _contentController,
                readOnly: true,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'QR content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  label: 'QR code for ${widget.payload.value}',
                  image: true,
                  child: SizedBox.square(
                    dimension: 320,
                    child: Image.memory(
                      widget.renderedQrBytes,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (verification != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      verification.code,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
              ] else ...[
                Text(
                  'No verification code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.payload.webUrl == null
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
                    onPressed: _saving || _saved
                        ? null
                        : () => unawaited(_saveCurrentQr()),
                    icon: Icon(
                      _saved
                          ? Icons.bookmark_added
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : _saved
                          ? 'Saved'
                          : 'Save QR',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _exporting
                        ? null
                        : () => unawaited(_shareQrImage()),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share QR image'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomizationUnlockSheet extends StatelessWidget {
  const CustomizationUnlockSheet({required this.entitlement, super.key});

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
              FilledButton.icon(
                onPressed:
                    entitlement.isBusy ||
                        !entitlement.isStoreAvailable ||
                        entitlement.price == null
                    ? null
                    : () => unawaited(entitlement.purchase()),
                icon: entitlement.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: Text(
                  entitlement.price == null
                      ? 'Lifetime unlock'
                      : 'Unlock lifetime customization',
                ),
              ),
              TextButton(
                onPressed: entitlement.isBusy || !entitlement.isStoreAvailable
                    ? null
                    : () => unawaited(entitlement.restore()),
                child: const Text('Restore purchase'),
              ),
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
