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
import '../../monetization/application/customization_entitlement.dart';

final class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.controller,
    this.customizationEntitlement,
    super.key,
  });

  final HistoryController controller;
  final Future<CustomizationEntitlement>? customizationEntitlement;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const QrEncoder _encoder = DartQrEncoder();
  static const _pngRenderer = QrPngRenderer();
  static const _classifier = QrPayloadClassifier();

  final _searchController = TextEditingController();
  bool _savedOnly = false;
  CustomizationEntitlement? _customizationEntitlement;

  @override
  void initState() {
    super.initState();
    unawaited(_bindCustomizationEntitlement());
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customizationEntitlement != widget.customizationEntitlement) {
      _customizationEntitlement?.removeListener(_syncExtendedHistory);
      _customizationEntitlement = null;
      unawaited(_bindCustomizationEntitlement());
    }
  }

  Future<void> _bindCustomizationEntitlement() async {
    final future = widget.customizationEntitlement;
    if (future == null) {
      await widget.controller.setExtendedHistoryUnlocked(true);
      return;
    }
    final entitlement = await future;
    if (!mounted) return;
    setState(() => _customizationEntitlement = entitlement);
    entitlement.addListener(_syncExtendedHistory);
    _syncExtendedHistory();
  }

  void _syncExtendedHistory() {
    final entitlement = _customizationEntitlement;
    if (entitlement == null) return;
    unawaited(
      widget.controller.setExtendedHistoryUnlocked(entitlement.isUnlocked),
    );
  }

  @override
  void dispose() {
    _customizationEntitlement?.removeListener(_syncExtendedHistory);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final enabled = widget.controller.enabled;
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: enabled ? _buildActions() : null,
          ),
          body: SafeArea(
            child: enabled ? _buildEnabledHistory() : _buildOptIn(),
          ),
        );
      },
    );
  }

  List<Widget> _buildActions() {
    return [
      PopupMenuButton<_HistoryMenuAction>(
        onSelected: (action) {
          switch (action) {
            case _HistoryMenuAction.clear:
              unawaited(_confirmClear());
            case _HistoryMenuAction.disable:
              unawaited(_confirmDisable());
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _HistoryMenuAction.clear,
            child: Text('Clear all history'),
          ),
          PopupMenuItem(
            value: _HistoryMenuAction.disable,
            child: Text('Turn off history'),
          ),
        ],
      ),
    ];
  }

  Widget _buildOptIn() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Keep a local QR history?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'When enabled, created and scanned values are stored only on '
              'this device. QR images are reconstructed from their decoded '
              'values; camera frames are never saved.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Free history gives you access to entries for one week. Older '
              'entries stay safely on this device and become available when '
              'you unlock lifetime customization.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => unawaited(widget.controller.enable()),
              icon: const Icon(Icons.check),
              label: const Text('Enable local history'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledHistory() {
    final query = _searchController.text.trim().toLowerCase();
    final sourceItems = _savedOnly
        ? widget.controller.savedItems
        : widget.controller.items;
    final items = sourceItems
        .where((item) {
          if (query.isEmpty) return true;
          return item.rawPayload.toLowerCase().contains(query) ||
              (item.title?.toLowerCase().contains(query) ?? false) ||
              (item.note?.toLowerCase().contains(query) ?? false) ||
              (item.displayHost?.toLowerCase().contains(query) ?? false) ||
              (item.verificationCode?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
    final groups = _groupByLocalDate(items);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search title, note, host, or text',
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('All'),
                icon: Icon(Icons.history),
              ),
              ButtonSegment(
                value: true,
                label: Text('Saved'),
                icon: Icon(Icons.bookmark_outline),
              ),
            ],
            selected: {_savedOnly},
            onSelectionChanged: (selection) =>
                setState(() => _savedOnly = selection.first),
          ),
        ),
        if (!_savedOnly && widget.controller.lockedItemCount > 0)
          _LockedHistoryCard(
            itemCount: widget.controller.lockedItemCount,
            onUnlock: _customizationEntitlement == null
                ? null
                : () => unawaited(_showHistoryUnlock()),
          ),
        Expanded(
          child: items.isEmpty
              ? _EmptyHistory(
                  searching: query.isNotEmpty,
                  savedOnly: _savedOnly,
                  hasLockedItems: widget.controller.lockedItemCount > 0,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final group in groups) ...[
                      _DateHeader(
                        localDate: group.localDate,
                        itemCount: group.items.length,
                        now: widget.controller.now,
                      ),
                      for (final item in group.items)
                        _HistoryTile(
                          item: item,
                          onToggleSaved: () async {
                            if (item.savedAtUtc == null) {
                              await widget.controller.save(item.id);
                              _showMessage('QR saved.');
                            } else {
                              await widget.controller.removeFromSaved(item.id);
                              _showMessage('Removed from Saved.');
                            }
                          },
                          confirmDelete: () => _confirmDelete(item),
                          onDelete: () => widget.controller.delete(item.id),
                          onOpen: () => _showDetails(item),
                        ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showHistoryUnlock() async {
    final entitlement = _customizationEntitlement;
    if (entitlement == null) return;

    void closeWhenUnlocked() {
      if (entitlement.isUnlocked && mounted) {
        Navigator.of(context).pop();
      }
    }

    entitlement.addListener(closeWhenUnlocked);
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => ListenableBuilder(
          listenable: entitlement,
          builder: (context, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unlock your full history',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your older QR codes are still stored privately on this '
                    'device. Unlock lifetime customization to view and reuse '
                    'them again.',
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
                    label: const Text('Unlock lifetime customization'),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed:
                        entitlement.isBusy || !entitlement.isStoreAvailable
                        ? null
                        : () => unawaited(entitlement.restore()),
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Restore purchases'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      entitlement.removeListener(closeWhenUnlocked);
    }
  }

  Future<void> _showDetails(QrHistoryItem item) {
    final qrPngBytes = _qrBytesFor(item);
    final payload = _classifier.classify(item.rawPayload);
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
                  item.title ??
                      (item.activityKind == QrActivityKind.created
                          ? 'Created QR'
                          : 'Scanned QR'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                if (item.title != null)
                  Text(
                    item.activityKind == QrActivityKind.created
                        ? 'Created QR'
                        : 'Scanned QR',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (qrPngBytes != null) ...[
                          Center(
                            child: SizedBox.square(
                              dimension: 240,
                              child: Image.memory(
                                qrPngBytes,
                                semanticLabel: 'QR code for ${item.rawPayload}',
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _copyQr(qrPngBytes, item.rawPayload),
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
                                onPressed: () =>
                                    _copyText(code, 'Verification code copied'),
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
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: SelectableText(item.rawPayload)),
                            IconButton(
                              onPressed: () =>
                                  _copyText(item.rawPayload, 'Payload copied'),
                              tooltip: 'Copy payload',
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
                              comparisonCode:
                                  item.activityKind == QrActivityKind.scanned
                                  ? item.verificationCode
                                  : null,
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
                    if (item.savedAtUtc == null)
                      TextButton.icon(
                        onPressed: () async {
                          await widget.controller.save(item.id);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (mounted) _showMessage('QR saved.');
                        },
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save'),
                      )
                    else
                      TextButton.icon(
                        onPressed: () async {
                          await widget.controller.removeFromSaved(item.id);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (mounted) _showMessage('Removed from Saved.');
                        },
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        label: const Text('Unsave'),
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
                        if (!await _confirmDelete(
                          item,
                          context: sheetContext,
                        )) {
                          return;
                        }
                        await widget.controller.delete(item.id);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          sheetContext,
                        ).colorScheme.error,
                      ),
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

  Future<bool> _editMetadata(QrHistoryItem item) async {
    var title = item.title ?? '';
    var note = item.note ?? '';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit history details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => title = value,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Displayed instead of raw content',
                ),
              ),
              const SizedBox(height: 12),
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

  Uint8List? _qrBytesFor(QrHistoryItem item) {
    if (item.qrPngBytes case final bytes?) return bytes;
    try {
      return _pngRenderer
          .render(_encoder.encode(item.rawPayload), size: 512)
          .bytes;
    } on Object {
      return null;
    }
  }

  Future<void> _copyText(String value, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage(confirmation);
  }

  Future<void> _copyQr(Uint8List bytes, String payload) async {
    try {
      await QrClipboard.copyPng(bytes: bytes, payload: payload);
      if (mounted) _showMessage('QR image copied');
    } on Object {
      if (mounted) _showMessage('The QR image could not be copied.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This removes every history entry. QRs in Saved will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await widget.controller.clear();
  }

  Future<bool> _confirmDelete(
    QrHistoryItem item, {
    BuildContext? context,
  }) async {
    final dialogContext = context ?? this.context;
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Delete history item?'),
        content: Text(
          item.savedAtUtc == null
              ? 'This permanently deletes the ${item.activityKind == QrActivityKind.created ? 'created' : 'scanned'} QR entry.'
              : 'This QR is marked as Saved. Deleting it will remove it permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmDisable() async {
    final choice = await showDialog<_DisableChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off history?'),
        content: const Text(
          'New activity will not be saved. Choose whether to keep or delete '
          'the history already on this device. Saved QRs will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DisableChoice.keep),
            child: const Text('Keep existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DisableChoice.delete),
            child: const Text('Delete existing'),
          ),
        ],
      ),
    );
    if (choice != null) {
      await widget.controller.disable(
        deleteExisting: choice == _DisableChoice.delete,
      );
    }
  }

  static List<_HistoryDateGroup> _groupByLocalDate(List<QrHistoryItem> items) {
    final sorted = [...items]
      ..sort(
        (first, second) => second.createdAtUtc.compareTo(first.createdAtUtc),
      );
    final groups = <_HistoryDateGroup>[];
    for (final item in sorted) {
      final local = item.createdAtUtc.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      if (groups.isEmpty || groups.last.localDate != date) {
        groups.add(_HistoryDateGroup(localDate: date, items: [item]));
      } else {
        groups.last.items.add(item);
      }
    }
    return groups;
  }
}

final class _HistoryDateGroup {
  _HistoryDateGroup({required this.localDate, required this.items});

  final DateTime localDate;
  final List<QrHistoryItem> items;
}

enum _HistoryMenuAction { clear, disable }

enum _DisableChoice { keep, delete }

final class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.localDate,
    required this.itemCount,
    this.now,
  });

  final DateTime localDate;
  final int itemCount;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final current = (now ?? DateTime.now)();
    final today = DateTime(current.year, current.month, current.day);
    final difference = today.difference(localDate).inDays;
    final label = switch (difference) {
      0 => 'Today',
      1 => 'Yesterday',
      _ =>
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-'
            '${localDate.day.toString().padLeft(2, '0')}',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '$itemCount',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

final class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.onToggleSaved,
    required this.confirmDelete,
    required this.onDelete,
    required this.onOpen,
  });

  final QrHistoryItem item;
  final VoidCallback onToggleSaved;
  final Future<bool> Function() confirmDelete;
  final Future<void> Function() onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final local = item.createdAtUtc.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final created = item.activityKind == QrActivityKind.created;
    final isSaved = item.savedAtUtc != null;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => unawaited(onDelete()),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(created ? Icons.qr_code_2 : Icons.qr_code_scanner),
        ),
        title: Text(
          item.title ?? item.displayHost ?? item.rawPayload,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${created ? 'Created' : 'Scanned'} · $time'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onToggleSaved,
              tooltip: isSaved ? 'Remove from saved' : 'Save QR',
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                color: isSaved ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            IconButton(
              onPressed: () async {
                if (await confirmDelete()) await onDelete();
              },
              tooltip: 'Delete history item',
              icon: const Icon(Icons.delete_outline),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

final class _LockedHistoryCard extends StatelessWidget {
  const _LockedHistoryCard({required this.itemCount, required this.onUnlock});

  final int itemCount;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final noun = itemCount == 1 ? 'QR code is' : 'QR codes are';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$itemCount older $noun locked',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing was deleted. Unlock lifetime customization to view, '
                'share, and reuse your full history.',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Unlock history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.searching,
    this.savedOnly = false,
    this.hasLockedItems = false,
  });

  final bool searching;
  final bool savedOnly;
  final bool hasLockedItems;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (savedOnly) {
      message = searching
          ? 'No saved history matches your search.'
          : 'No saved QR codes yet. Tap the bookmark icon on any item to save it.';
    } else if (hasLockedItems && !searching) {
      message = 'No QR activity from the past week.';
    } else {
      message = searching
          ? 'No history matches your search.'
          : 'Created and scanned QR codes will appear here.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
