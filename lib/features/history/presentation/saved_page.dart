import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../create/presentation/generated_barcode_page.dart';
import '../../create/application/qr_encoder.dart';
import '../../create/data/dart_qr_encoder.dart';
import '../../create/data/qr_png_renderer.dart';
import '../../scan/domain/qr_payload_classifier.dart';
import '../../scan/domain/scanned_code.dart';
import '../../scan/presentation/qr_payload_action.dart';
import '../../scan/presentation/qr_link_review.dart';
import '../../lookup/domain/gs1_digital_link.dart';
import '../../lookup/presentation/gs1_details.dart';
import '../../lookup/domain/identifier_recognizer.dart';
import '../../lookup/presentation/identifier_details.dart';
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
  String? _selectedCollection;
  static const _unfiled = 'unfiled';

  bool _sensitive(QrHistoryItem item) {
    final payload = _classifier.classify(item.rawPayload);
    final raw = item.rawPayload.trimLeft().toUpperCase();
    return raw.startsWith('WIFI:') ||
        raw.startsWith('FIDO:') ||
        payload.sensitiveValue != null ||
        payload.type == QrContentType.passkey;
  }

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
        final organization = widget.controller.organization;
        final selected =
            _selectedCollection == _unfiled ||
                organization.collections.any(
                  (value) => value.id == _selectedCollection,
                )
            ? _selectedCollection
            : null;
        final items = widget.controller.savedItems
            .where((item) {
              final memberships = organization.memberships[item.id] ?? const [];
              if (selected == _unfiled && memberships.isNotEmpty) return false;
              if (selected != null &&
                  selected != _unfiled &&
                  !memberships.contains(selected)) {
                return false;
              }
              if (query.isEmpty) return true;
              return (!_sensitive(item) &&
                      item.rawPayload.toLowerCase().contains(query)) ||
                  (item.title?.toLowerCase().contains(query) ?? false) ||
                  (item.note?.toLowerCase().contains(query) ?? false) ||
                  (item.displayHost?.toLowerCase().contains(query) ?? false) ||
                  item.codeFormat.label.toLowerCase().contains(query) ||
                  (organization.tags[item.id] ?? const []).any(
                    (tag) => tag.toLowerCase().contains(query),
                  );
            })
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Saved Codes'),
            actions: [
              if (widget.controller.organizationAvailable) ...[
                IconButton(
                  onPressed: () => _editCollection(),
                  tooltip: 'New collection',
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                IconButton(
                  onPressed: _manageCollections,
                  tooltip: 'Manage collections',
                  icon: const Icon(Icons.folder_outlined),
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (widget.controller.organizationAvailable)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Saved'),
                          selected: selected == null,
                          onSelected: (_) =>
                              setState(() => _selectedCollection = null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Unfiled'),
                          selected: selected == _unfiled,
                          onSelected: (_) =>
                              setState(() => _selectedCollection = _unfiled),
                        ),
                        for (final collection in organization.collections) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(collection.name),
                            selected: selected == collection.id,
                            onSelected: (_) => setState(
                              () => _selectedCollection = collection.id,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search saved codes, notes, or tags',
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
                      ? _SavedEmpty(
                          searching: query.isNotEmpty,
                          filtered: selected != null,
                          unfiled: selected == _unfiled,
                        )
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
                                    (_sensitive(item)
                                        ? _classifier
                                              .classify(item.rawPayload)
                                              .title
                                        : item.rawPayload),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.note != null)
                                    Text(
                                      item.note!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    [
                                      item.codeFormat.label,
                                      if (_sensitive(item)) 'Sensitive content',
                                      ...(organization.tags[item.id] ??
                                          const <String>[]),
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
    final digitalLink = const Gs1DigitalLinkParser().parse(item.rawPayload);
    final identifier = const IdentifierRecognizer().recognize(
      value: item.rawPayload,
      format: item.codeFormat,
    );
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
                  item.title ?? 'Saved ${item.codeFormat.label}',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                Text(
                  '${item.codeFormat.label} · ${item.source.label}',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!payload.isEphemeral &&
                            item.activityKind == QrActivityKind.created &&
                            item.codeFormat != ScannedCodeFormat.qrCode) ...[
                          StoredBarcodeButton(
                            value: item.rawPayload,
                            format: item.codeFormat,
                          ),
                          const SizedBox(height: 16),
                        ],
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
                        if (digitalLink != null) ...[
                          Gs1Details(link: digitalLink),
                          const SizedBox(height: 16),
                        ],
                        if (identifier != null) ...[
                          IdentifierDetails(recognition: identifier),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          'Raw content',
                          style: Theme.of(sheetContext).textTheme.labelLarge,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: QrRawContent(payload: payload)),
                            IconButton(
                              onPressed: () => _copyText(item.rawPayload),
                              tooltip: 'Copy raw content',
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ],
                        ),
                        if (payload.linkInspection case final inspection?
                            when identifier == null || payload.canRoute) ...[
                          const SizedBox(height: 12),
                          QrLinkReview(inspection: inspection),
                        ],
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
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    if (widget.controller.organizationAvailable)
                      TextButton.icon(
                        onPressed: () async {
                          if (await _organize(item) && sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.folder_copy_outlined),
                        label: const Text('Organize'),
                      ),
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

  Future<void> _editCollection({String? id, String initialName = ''}) async {
    var name = initialName;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(id == null ? 'New collection' : 'Rename collection'),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Collection name'),
          onChanged: (value) => name = value,
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
    if (accepted != true) return;
    try {
      if (id == null) {
        await widget.controller.createCollection(name);
      } else {
        await widget.controller.renameCollection(id, name);
      }
    } on ArgumentError catch (error) {
      if (mounted) _message(error.message.toString());
    } on Object {
      if (mounted) _message('The collection could not be saved.');
    }
  }

  Future<void> _manageCollections() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Manage collections'),
              subtitle: Text('Deleting a collection keeps its Saved items.'),
            ),
            for (final collection in widget.controller.organization.collections)
              ListTile(
                title: Text(collection.name),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Rename ${collection.name}',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editCollection(
                        id: collection.id,
                        initialName: collection.name,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete ${collection.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: Text('Delete ${collection.name}?'),
                            content: const Text(
                              'Only the collection is deleted. Its codes stay in Saved.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        try {
                          await widget.controller.deleteCollection(
                            collection.id,
                          );
                        } on Object {
                          if (mounted) {
                            _message('The collection could not be deleted.');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            if (widget.controller.organization.collections.isEmpty)
              const ListTile(
                title: Text(
                  'No collections yet. Use New collection to create one.',
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<bool> _organize(QrHistoryItem item) async {
    final organization = widget.controller.organization;
    final selected = (organization.memberships[item.id] ?? const <String>[])
        .toSet();
    var tags = (organization.tags[item.id] ?? const <String>[]).join(', ');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Organize saved code'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final collection in organization.collections)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(collection.name),
                      value: selected.contains(collection.id),
                      onChanged: (value) => setDialogState(() {
                        if (value == true) {
                          selected.add(collection.id);
                        } else {
                          selected.remove(collection.id);
                        }
                      }),
                    ),
                  if (organization.collections.isEmpty)
                    const Text(
                      'Create a collection from Saved to file this code.',
                    ),
                  TextFormField(
                    initialValue: tags,
                    onChanged: (value) => tags = value,
                    maxLength: 840,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      helperText: 'Separate up to 20 tags with commas.',
                    ),
                  ),
                ],
              ),
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
      ),
    );
    if (accepted != true) return false;
    try {
      await widget.controller.organizeSavedItem(
        item.id,
        collectionIds: selected,
        tags: tags.split(','),
      );
      return true;
    } on ArgumentError catch (error) {
      if (mounted) _message(error.message.toString());
    } on Object {
      if (mounted) _message('The saved code could not be organized.');
    }
    return false;
  }

  Future<bool> _editMetadata(QrHistoryItem item) async {
    var title = item.title ?? '';
    var note = item.note ?? '';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit saved code'),
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
    if (item.codeFormat != ScannedCodeFormat.qrCode) return null;
    if (_classifier.classify(item.rawPayload).isEphemeral) return null;
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
  const _SavedEmpty({
    required this.searching,
    this.filtered = false,
    this.unfiled = false,
  });

  final bool searching;
  final bool filtered;
  final bool unfiled;

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
                  : filtered
                  ? (unfiled
                        ? 'No unfiled codes.'
                        : 'No codes in this collection.')
                  : 'Save useful QRs for quick access.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              const Text(
                'Saved codes stay here even when History is cleared or older entries are locked.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
