import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../create/application/qr_encoder.dart';
import '../../create/data/dart_qr_encoder.dart';
import '../../create/data/qr_png_renderer.dart';
import '../../scan/domain/qr_payload_classifier.dart';
import '../../scan/presentation/qr_payload_action.dart';
import '../application/history_controller.dart';
import '../application/qr_clipboard.dart';
import '../domain/qr_history.dart';

final class SavedPage extends StatefulWidget {
  const SavedPage({required this.controller, super.key});

  final HistoryController controller;

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  static const QrEncoder _encoder = DartQrEncoder();
  static const _renderer = QrPngRenderer();
  static const _classifier = QrPayloadClassifier();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final items = widget.controller.savedItems
            .where((item) {
              if (query.isEmpty) return true;
              return item.rawPayload.toLowerCase().contains(query) ||
                  (item.title?.toLowerCase().contains(query) ?? false) ||
                  (item.note?.toLowerCase().contains(query) ?? false) ||
                  (item.displayHost?.toLowerCase().contains(query) ?? false);
            })
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(title: const Text('Saved QRs')),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search saved QRs',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                        ),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? _SavedEmpty(searching: query.isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.bookmark_outline),
                              ),
                              title: Text(
                                item.title ??
                                    item.displayHost ??
                                    item.rawPayload,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: item.note == null
                                  ? null
                                  : Text(
                                      item.note!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDetails(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetails(QrHistoryItem item) {
    final payload = _classifier.classify(item.rawPayload);
    final qrBytes = _qrBytesFor(item);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? 'Saved QR',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (qrBytes != null) ...[
                          Center(
                            child: SizedBox.square(
                              dimension: 240,
                              child: Image.memory(
                                qrBytes,
                                semanticLabel: 'QR code for ${item.rawPayload}',
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _copyQr(qrBytes, item.rawPayload),
                              icon: const Icon(Icons.copy_all_outlined),
                              label: const Text('Copy QR image'),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (item.verificationCode case final code?) ...[
                          Text(
                            'Verification code',
                            style: Theme.of(sheetContext).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  code,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyText(
                                  code,
                                  'Verification code copied.',
                                ),
                                tooltip: 'Copy verification code',
                                icon: const Icon(Icons.copy_outlined),
                              ),
                            ],
                          ),
                          if (item.registrableDomain case final domain?)
                            Text(domain),
                          const SizedBox(height: 20),
                        ],
                        if (item.note case final note?) ...[
                          Text(
                            'Note',
                            style: Theme.of(sheetContext).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(note),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          'Raw content',
                          style: Theme.of(sheetContext).textTheme.labelLarge,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: SelectableText(item.rawPayload)),
                            IconButton(
                              onPressed: () => _copyText(item.rawPayload),
                              tooltip: 'Copy raw content',
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ],
                        ),
                        if (payload.canRoute) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => routeQrPayload(
                              sheetContext,
                              payload,
                              comparisonCode: item.verificationCode,
                            ),
                            icon: Icon(payload.icon),
                            label: Text(payload.actionLabel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await _editMetadata(item);
                        if (updated && sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        if (!await _confirmRemove(item)) return;
                        await widget.controller.removeFromSaved(item.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.bookmark_remove_outlined),
                      label: const Text('Remove'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _editMetadata(QrHistoryItem item) async {
    var title = item.title ?? '';
    var note = item.note ?? '';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit saved QR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => title = value,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextFormField(
                initialValue: note,
                onChanged: (value) => note = value,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return false;
    await widget.controller.updateMetadata(item.id, title: title, note: note);
    return true;
  }

  Future<bool> _confirmRemove(QrHistoryItem item) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from Saved?'),
            content: Text(
              item.isInHistory
                  ? 'This QR will remain in History.'
                  : 'This permanently deletes this QR because it is no longer in History.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Uint8List? _qrBytesFor(QrHistoryItem item) {
    if (item.qrPngBytes case final bytes?) return bytes;
    try {
      return _renderer
          .render(_encoder.encode(item.rawPayload), size: 512)
          .bytes;
    } on Object {
      return null;
    }
  }

  Future<void> _copyText(
    String text, [
    String message = 'Raw content copied.',
  ]) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _message(message);
  }

  Future<void> _copyQr(Uint8List bytes, String payload) async {
    try {
      await QrClipboard.copyPng(bytes: bytes, payload: payload);
      if (mounted) _message('QR image copied.');
    } on Object {
      if (mounted) _message('The QR image could not be copied.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _SavedEmpty extends StatelessWidget {
  const _SavedEmpty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'No saved QRs match your search.'
                  : 'Save useful QRs for quick access.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              const Text(
                'Saved QRs stay here even when History is cleared or older entries are locked.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
