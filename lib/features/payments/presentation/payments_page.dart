import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../history/application/qr_clipboard.dart';
import '../../scan/domain/link_inspection.dart';
import '../../scan/presentation/qr_link_review.dart';
import '../domain/payment_workspace.dart';
import '../data/local_payments_repository.dart';
import '../application/payments_entitlement.dart';
import '../application/payments_controller.dart';
import '../application/payment_qr.dart';
import '../application/payments_files.dart';

String _paymentError(Object error) => switch (error) {
  FormatException e => e.message,
  StateError e => e.message,
  _ =>
    'Payments could not complete this action. Your saved records have been kept.',
};

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    required this.entitlement,
    this.openRepository,
    super.key,
  });
  final PaymentsEntitlement entitlement;
  final Future<PaymentsRepository> Function()? openRepository;
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _opening = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(PaymentsFiles.cleanup().catchError((Object _) {}));
  }

  Future<void> _open(bool sample) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    PaymentsController? controller;
    try {
      controller = sample
          ? await PaymentsController.demo(widget.entitlement)
          : PaymentsController(
              repository:
                  await (widget.openRepository ??
                      LocalPaymentsRepository.open)(),
              entitlement: widget.entitlement,
            );
      await controller.refresh();
      if (!mounted) {
        await controller.close();
        return;
      }
      final c = controller;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentWorkspacePage(controller: c),
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = _paymentError(error));
    } finally {
      await controller?.close();
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payments')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.entitlement,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.payments_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Your payment links, organized',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Manage profiles and reusable QR cards. Your payment provider handles checkout. Scanning and ordinary QR creation stay free.',
            ),
            const SizedBox(height: 20),
            PaymentsAccessCard(entitlement: widget.entitlement),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _opening ? null : () => _open(true),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explore sample workspace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _opening ? null : () => _open(false),
              icon: const Icon(Icons.folder_outlined),
              label: Text(
                widget.entitlement.isOwned
                    ? 'Open payment workspace'
                    : 'View saved payment records',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sample changes stay in memory and cannot be exported. Existing local records can always be viewed, deleted or exported as data.',
            ),
            if (_opening) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!),
              ),
          ],
        ),
      ),
    ),
  );
}

class PaymentsAccessCard extends StatefulWidget {
  const PaymentsAccessCard({required this.entitlement, super.key});
  final PaymentsEntitlement entitlement;
  @override
  State<PaymentsAccessCard> createState() => _PaymentsAccessCardState();
}

class _PaymentsAccessCardState extends State<PaymentsAccessCard> {
  String? _error;
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'The store action could not be completed. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.entitlement,
    builder: (context, _) {
      final e = widget.entitlement;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.isOwned ? 'Payments unlocked' : 'Separate Payments unlock',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(e.message),
              const SizedBox(height: 8),
              const Text(
                'Independent of Dali QR Custom. No merchant payment is made by buying this package.',
              ),
              if (e.localizedPrice != null) Text(e.localizedPrice!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: e.canPurchase && !e.isOwned
                        ? () => _act(e.purchase)
                        : null,
                    child: const Text('Unlock Payments'),
                  ),
                  TextButton(
                    onPressed: e.canRestore ? () => _act(e.restore) : null,
                    child: const Text('Restore Payments'),
                  ),
                ],
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      );
    },
  );
}

class PaymentWorkspacePage extends StatefulWidget {
  const PaymentWorkspacePage({required this.controller, super.key});
  final PaymentsController controller;
  @override
  State<PaymentWorkspacePage> createState() => _PaymentWorkspacePageState();
}

class _PaymentWorkspacePageState extends State<PaymentWorkspacePage> {
  bool _profiles = false;
  bool _archived = false;
  String? _error;
  PaymentsController get c => widget.controller;
  Future<void> _act(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _error = _paymentError(error));
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  Future<T?> _editDialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    final result = await Navigator.of(context).push(route);
    await route.completed;
    return result;
  }

  Future<void> _profile([PaymentProfile? profile]) async {
    if (!c.canManage) return;
    final name = TextEditingController(text: profile?.label ?? '');
    final link = TextEditingController(
      text: profile?.link ?? (c.sample ? PaymentPolicy.sampleLink : ''),
    );
    final notes = TextEditingController(text: profile?.notes ?? '');
    try {
      final fields = await _editDialog<List<String>>(
        (context) => AlertDialog(
          title: Text(
            profile == null ? 'New payment profile' : 'Edit payment profile',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Profile name'),
                ),
                TextField(
                  controller: link,
                  readOnly: c.sample,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Official HTTPS payment link',
                  ),
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  c.sample
                      ? 'The demo link is fixed. Sample changes are not saved.'
                      : 'Labels are not verified merchant identities. Editing this profile does not change existing template links.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, [name.text, link.text, notes.text]),
              child: const Text('Save profile'),
            ),
          ],
        ),
      );
      if (fields != null && mounted) {
        await _act(
          () => c.saveProfile(
            id: profile?.id,
            label: fields[0],
            link: fields[1],
            notes: fields[2],
          ),
        );
      }
    } finally {
      name.dispose();
      link.dispose();
      notes.dispose();
    }
  }

  Future<void> _template([PaymentTemplate? template]) async {
    if (!c.canManage || c.profiles.isEmpty) return;
    var profileId = template?.profileId ?? c.profiles.first.id;
    var updateLink = false;
    final name = TextEditingController(text: template?.label ?? '');
    try {
      final result = await _editDialog<(String, String, bool)>(
        (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              template == null
                  ? 'New payment template'
                  : 'Edit payment template',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: profileId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment profile',
                    ),
                    items: [
                      for (final p in c.profiles)
                        DropdownMenuItem(value: p.id, child: Text(p.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => profileId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (template != null &&
                      profileId == template.profileId &&
                      c.profiles.firstWhere((p) => p.id == profileId).link !=
                          template.link)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use the updated profile link'),
                      value: updateLink,
                      onChanged: (value) =>
                          setDialogState(() => updateLink = value ?? false),
                    ),
                  SelectableText(
                    template != null &&
                            profileId == template.profileId &&
                            !updateLink
                        ? template.link
                        : c.profiles.firstWhere((p) => p.id == profileId).link,
                  ),
                  const Text(
                    'Review this link before saving a Draft. Existing printed or shared codes stay unchanged.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (profileId, name.text, updateLink)),
                child: const Text('Save draft'),
              ),
            ],
          ),
        ),
      );
      if (result != null && mounted) {
        await _act(
          () => c.saveTemplate(
            id: template?.id,
            profileId: result.$1,
            label: result.$2,
            updateLink: result.$3,
          ),
        );
      }
    } finally {
      name.dispose();
    }
  }

  Future<void> _preview(PaymentTemplate t) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PaymentCardPage(controller: c, templateId: t.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _dataAction(String action) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    if (action == 'access') {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: SingleChildScrollView(
            child: PaymentsAccessCard(entitlement: c.entitlement),
          ),
        ),
      );
    } else if (action == 'export' &&
        await _confirm(
          'Export payment records?',
          'The JSON file contains your saved links and notes. Only share it with people you trust.',
        )) {
      await _act(
        () => PaymentsFiles.share(
          Uint8List.fromList(utf8.encode(c.exportRecords())),
          records: true,
          origin: origin,
        ),
      );
    } else if (action == 'delete' &&
        await _confirm(
          'Delete local Payments data?',
          'This deletes only payment profiles and templates. Provider links remain active; ordinary History and Saved are unchanged.',
        )) {
      await _act(c.clear);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.entitlement]),
    builder: (context, _) {
      final templates = c.templates
          .where((t) => (t.state == PaymentTemplateState.archived) == _archived)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(c.sample ? 'Payments sample' : 'Payment workspace'),
          actions: [
            PopupMenuButton<String>(
              onSelected: _dataAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'access',
                  child: Text('Payments access'),
                ),
                if (!c.sample)
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Export payment records'),
                  ),
                if (!c.sample)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete local Payments data'),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              if (c.sample)
                const Text(
                  'DEMO · Changes are not saved. This sample QR cannot receive payments.',
                )
              else if (!c.canManage)
                const Text(
                  'Read-only access. View, export your original records or delete them; management requires the separate Payments unlock.',
                ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Templates')),
                  ButtonSegment(value: true, label: Text('Profiles')),
                ],
                selected: {_profiles},
                onSelectionChanged: (v) => setState(() => _profiles = v.single),
              ),
              const SizedBox(height: 16),
              if (_profiles) ...[
                FilledButton.icon(
                  onPressed: c.canManage && !c.busy ? _profile : null,
                  icon: const Icon(Icons.add),
                  label: const Text('New profile'),
                ),
                if (c.profiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No payment profiles yet.'),
                  ),
                for (final p in c.profiles)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SelectableText(p.link),
                          if (p.notes.isNotEmpty) Text(p.notes),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: c.canManage && !c.busy
                                    ? () => _profile(p)
                                    : null,
                                child: const Text('Edit profile'),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () async {
                                        if (await _confirm(
                                          'Delete profile?',
                                          'Existing templates must be deleted first. This does not deactivate the provider link.',
                                        )) {
                                          await _act(
                                            () => c.deleteProfile(p.id),
                                          );
                                        }
                                      },
                                child: const Text('Delete profile'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                FilledButton.icon(
                  onPressed: c.canManage && !c.busy && c.profiles.isNotEmpty
                      ? _template
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('New template'),
                ),
                if (c.profiles.isEmpty)
                  const Text('Create a payment profile first, using Profiles.'),
                FilterChip(
                  label: const Text('Archived templates'),
                  selected: _archived,
                  onSelected: (v) => setState(() => _archived = v),
                ),
                if (templates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No templates in this view.'),
                  ),
                for (final t in templates)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('Local status: ${t.state.name}'),
                          const Text(
                            'Status does not indicate payment or provider-link availability.',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _preview(t),
                                child: const Text('Review QR card'),
                              ),
                              TextButton(
                                onPressed: c.canManage && !c.busy
                                    ? () => _template(t)
                                    : null,
                                child: const Text('Edit template'),
                              ),
                              TextButton(
                                onPressed: c.canManage && !c.busy
                                    ? () => _act(() => c.duplicate(t.id))
                                    : null,
                                child: const Text('Duplicate'),
                              ),
                              TextButton(
                                onPressed: c.canManage && !c.busy
                                    ? () => _act(
                                        () => c.setStateFor(
                                          t.id,
                                          _archived
                                              ? PaymentTemplateState.draft
                                              : PaymentTemplateState.archived,
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  _archived ? 'Restore to Draft' : 'Archive',
                                ),
                              ),
                              TextButton(
                                onPressed: c.busy
                                    ? null
                                    : () async {
                                        if (await _confirm(
                                          'Delete template?',
                                          'This removes only the local template. Printed codes and the provider link are unchanged.',
                                        )) {
                                          await _act(
                                            () => c.deleteTemplate(t.id),
                                          );
                                        }
                                      },
                                child: const Text('Delete template'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (c.busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class PaymentCardPage extends StatefulWidget {
  const PaymentCardPage({
    required this.controller,
    required this.templateId,
    super.key,
  });
  final PaymentsController controller;
  final String templateId;
  @override
  State<PaymentCardPage> createState() => _PaymentCardPageState();
}

class _PaymentCardPageState extends State<PaymentCardPage> {
  late Future<PaymentQrArtifact> _preview;
  String? _previewLabel, _previewLink;
  bool _busy = false;
  String? _message;
  PaymentsController get c => widget.controller;
  void _prepare(PaymentTemplate t) {
    if (_previewLabel != t.label || _previewLink != t.link) {
      _previewLabel = t.label;
      _previewLink = t.link;
      _preview = PaymentQr.render(t, sample: c.sample);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare(c.templates.firstWhere((t) => t.id == widget.templateId));
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _message = _paymentError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.entitlement]),
    builder: (context, _) {
      final t = c.templates.where((t) => t.id == widget.templateId).firstOrNull;
      if (t == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Payment card')),
          body: const Center(child: Text('This template no longer exists.')),
        );
      }
      _prepare(t);
      final export =
          c.canExport && t.state == PaymentTemplateState.ready && !_busy;
      return Scaffold(
        appBar: AppBar(title: const Text('Review payment QR')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(t.label, style: Theme.of(context).textTheme.titleLarge),
              QrLinkReview(inspection: const LinkInspector().inspect(t.link)),
              const Text(
                'This label is not a verified merchant identity. Confirm the recipient and amount at the provider checkout.',
              ),
              FutureBuilder<PaymentQrArtifact>(
                future: _preview,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'The payment card could not be rendered.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Image.memory(
                    snapshot.data!.cardPng,
                    semanticLabel: c.sample
                        ? 'Sample payment QR card, not for payment'
                        : 'Payment QR card',
                    filterQuality: FilterQuality.none,
                  );
                },
              ),
              Text('Local status: ${t.state.name}'),
              if (c.sample)
                const Text('Sample preview only. Export is disabled.'),
              if (c.canManage && t.state == PaymentTemplateState.draft)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => c.setStateFor(t.id, PaymentTemplateState.ready),
                        ),
                  child: const Text('Validate and mark Ready'),
                ),
              OutlinedButton(
                onPressed: export
                    ? () => _action(() async {
                        final artifact = await c.exportArtifact(t.id);
                        await QrClipboard.copyPng(
                          bytes: artifact.qrPng,
                          payload: artifact.link,
                        );
                        if (mounted) {
                          setState(() => _message = 'Payment QR copied.');
                        }
                      })
                    : null,
                child: const Text('Copy payment QR'),
              ),
              OutlinedButton(
                onPressed: export
                    ? () => _action(() async {
                        final artifact = await c.exportArtifact(t.id);
                        if (!context.mounted) return;
                        final box = context.findRenderObject() as RenderBox?;
                        await PaymentsFiles.share(
                          artifact.cardPng,
                          records: false,
                          origin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        );
                      })
                    : null,
                child: const Text('Share payment card'),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      );
    },
  );
}
