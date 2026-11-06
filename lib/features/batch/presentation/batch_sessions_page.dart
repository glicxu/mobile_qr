import 'dart:async';

import 'package:flutter/material.dart';

import '../../scan/domain/scanned_code.dart';
import '../../scan/domain/qr_payload_classifier.dart';
import '../../scan/presentation/qr_payload_action.dart';
import '../../scan/presentation/qr_scanner_page.dart';
import '../../secure_qr/domain/secure_qr_service.dart';
import '../application/batch_export.dart';
import '../data/local_batch_repository.dart';
import '../domain/batch_session.dart';

final class BatchSessionsPage extends StatefulWidget {
  const BatchSessionsPage({
    required this.secureQrService,
    this.repository,
    super.key,
  });
  final SecureQrService secureQrService;
  final BatchRepository? repository;
  @override
  State<BatchSessionsPage> createState() => _BatchSessionsPageState();
}

class _BatchSessionsPageState extends State<BatchSessionsPage> {
  BatchRepository? _repository;
  List<BatchSession> _sessions = const [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final repository = widget.repository ?? await LocalBatchRepository.open();
      if (!mounted) {
        if (widget.repository == null) await repository.close();
        return;
      }
      _repository = repository;
      await _refresh();
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Protected batch storage could not be opened on this device.';
        });
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final sessions = await _repository!.listSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sessions could not be loaded.';
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) unawaited(_repository?.close());
    super.dispose();
  }

  Future<void> _create() async {
    var name = 'Batch ${_sessions.length + 1}';
    var counts = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start a batch session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scans are saved only on this device until you delete the session. Credentials and personal structured payloads are excluded.',
                ),
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Session name'),
                  onChanged: (value) => name = value,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Count duplicates'),
                  subtitle: const Text(
                    'Each Scan next action accepts one capture. Otherwise duplicates are ignored.',
                  ),
                  value: counts,
                  onChanged: (value) => setDialogState(() => counts = value),
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
              child: const Text('Start session'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      final session = await _repository!.createSession(
        name,
        countDuplicates: counts,
      );
      if (mounted) await _resume(session);
    } on ArgumentError catch (error) {
      if (mounted) _message(error.message.toString());
    } on Object {
      if (mounted) _message('The session could not be created.');
    }
  }

  Future<void> _resume(BatchSession session) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BatchSessionPage(
          repository: _repository!,
          session: session,
          secureQrService: widget.secureQrService,
        ),
      ),
    );
    await _refresh();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _delete(BatchSession session) async {
    final accepted = await confirmBatchDeletion(
      context,
      'Delete session?',
      'This permanently deletes this local session and its scans.',
    );
    if (!accepted) return;
    try {
      await _repository!.deleteSession(session.id);
      await _refresh();
    } on Object {
      if (mounted) _message('The session could not be deleted.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Batch sessions')),
    floatingActionButton: _repository == null
        ? null
        : FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('New session'),
          ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _repository == null ? _open : _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : _sessions.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Create a local session to scan, count, review, and export codes. History settings do not control batch sessions.',
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return ListTile(
                title: Text(session.name),
                subtitle: Text(
                  '${session.itemCount} distinct codes · ${session.countDuplicates ? 'Count duplicates' : 'Unique codes'}',
                ),
                onTap: () => _resume(session),
                trailing: IconButton(
                  tooltip: 'Delete session',
                  onPressed: () => _delete(session),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          ),
  );
}

final class BatchSessionPage extends StatefulWidget {
  const BatchSessionPage({
    required this.repository,
    required this.session,
    required this.secureQrService,
    this.capture,
    this.export,
    super.key,
  });
  final BatchRepository repository;
  final BatchSession session;
  final SecureQrService secureQrService;
  final Future<ScannedCode?> Function(BuildContext)? capture;
  final Future<void> Function(List<BatchItem>, Rect?)? export;
  @override
  State<BatchSessionPage> createState() => _BatchSessionPageState();
}

class _BatchSessionPageState extends State<BatchSessionPage> {
  List<BatchItem> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final items = await widget.repository.items(widget.session.id);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'The session could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final capture = widget.capture;
      final code = capture != null
          ? await capture(context)
          : await Navigator.of(context).push<ScannedCode>(
              MaterialPageRoute(
                builder: (scanContext) => QrScannerPage(
                  secureQrService: widget.secureQrService,
                  onCodeSelected: (value) => Navigator.pop(scanContext, value),
                ),
              ),
            );
      if (code != null) {
        final accepted = await widget.repository.addCode(
          widget.session.id,
          code,
        );
        await _refresh();
        _message(
          accepted
              ? 'Code recorded.'
              : 'Duplicate ignored in this unique-code session.',
        );
      }
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    } on Object {
      _message('The code could not be recorded.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quantity(BatchItem item) async {
    var value = item.quantity.toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit quantity'),
        content: TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            helperText: '1 to 999999',
          ),
          onChanged: (text) => value = text,
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
      await widget.repository.setQuantity(item.id, int.tryParse(value) ?? 0);
      await _refresh();
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    } on Object {
      _message('The quantity could not be changed.');
    }
  }

  Future<void> _remove(BatchItem item) async {
    if (!await confirmBatchDeletion(
      context,
      'Remove item?',
      'This removes this row and its quantity from the session.',
    )) {
      return;
    }
    try {
      await widget.repository.removeItem(item.id);
      await _refresh();
    } on Object {
      _message('The item could not be removed.');
    }
  }

  Future<void> _export(BuildContext buttonContext) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export CSV?'),
          content: const Text(
            'Formula-like values are exported as text. Spreadsheet apps may change leading zeroes. Original scan values stay in this session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Share CSV'),
            ),
          ],
        ),
      );
      if (accepted != true || !buttonContext.mounted) return;
      final renderBox = buttonContext.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final rows = await widget.repository.items(widget.session.id);
      if (widget.export case final export?) {
        await export(rows, origin);
      } else {
        await const BatchExport().share(rows, origin: origin);
      }
    } on Object {
      _message('CSV export could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.session.name),
      actions: [
        Builder(
          builder: (buttonContext) => IconButton(
            tooltip: 'Export CSV',
            onPressed: _busy || _items.isEmpty
                ? null
                : () => _export(buttonContext),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy || _error != null ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(_busy ? 'Working…' : 'Scan next'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.maybePop(context),
                        child: const Text('Pause session'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        widget.session.countDuplicates
                            ? 'Count mode: each capture adds one.'
                            : 'Unique mode: duplicates are ignored.',
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan next accepts one code. This session stays on your device until deleted.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loading || _error != null || _items.isEmpty)
            SliverToBoxAdapter(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: TextButton(
                        onPressed: _refresh,
                        child: Text('$_error Retry'),
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(child: Text('No scans yet. Choose Scan next.'))
                  : const SizedBox.shrink(),
            ),
          if (!_loading && _error == null && _items.isNotEmpty)
            SliverList.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(
                    const QrPayloadClassifier()
                        .classify(item.value)
                        .previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.format.label} · ${item.sourceLabel}\nQuantity: ${item.quantity}',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(item.format.label),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            QrRawContent(
                              payload: const QrPayloadClassifier().classify(
                                item.value,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Quantity: ${item.quantity}'),
                            Text('First source: ${item.sourceLabel}'),
                            Text(
                              'First capture: ${item.firstSeenUtc.toLocal()}',
                            ),
                            Text('Last capture: ${item.lastSeenUtc.toLocal()}'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit quantity',
                        onPressed: _busy ? null : () => _quantity(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        onPressed: _busy ? null : () => _remove(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

Future<bool> confirmBatchDeletion(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    ) ??
    false;
