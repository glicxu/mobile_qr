import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:drift/native.dart';

import '../domain/payment_workspace.dart';
import '../data/local_payments_repository.dart';
import '../data/payments_database.dart';
import 'payment_qr.dart';
import 'payments_entitlement.dart';

final class PaymentsController extends ChangeNotifier {
  PaymentsController({
    required this.repository,
    required this.entitlement,
    this.sample = false,
  });
  final PaymentsRepository repository;
  final PaymentsEntitlement entitlement;
  final bool sample;
  List<PaymentProfile> profiles = const [];
  List<PaymentTemplate> templates = const [];
  bool _busy = false;
  bool _closed = false;
  Future<void>? _pending;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  bool get busy => _busy;
  bool get canManage => sample || entitlement.isOwned;
  bool get canExport => !sample && entitlement.isOwned;
  final _random = Random.secure();
  String _id() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  void _requireManage() {
    if (_closed || !canManage) {
      throw StateError('Payments management requires its own unlock.');
    }
  }

  Future<void> refresh() async {
    if (_closed) return;
    profiles = List.unmodifiable(await repository.profiles());
    templates = List.unmodifiable(await repository.templates());
    _notify();
  }

  Future<void> _write(
    Future<void> Function() action, {
    bool managed = true,
  }) async {
    if (_closed) throw StateError('This Payments workspace is closed.');
    if (_busy) throw StateError('A Payments change is still in progress.');
    if (managed) _requireManage();
    final done = Completer<void>();
    _pending = done.future;
    _busy = true;
    _notify();
    try {
      await action();
      await refresh();
    } finally {
      _busy = false;
      _notify();
      done.complete();
    }
  }

  Future<void> saveProfile({
    String? id,
    required String label,
    required String link,
    String notes = '',
  }) => _write(() async {
    final name = PaymentPolicy.text(label, 'a profile name');
    PaymentPolicy.link(link);
    if (sample && link != PaymentPolicy.sampleLink) {
      throw StateError('The sample workspace uses a fixed demo link.');
    }
    final old = profiles.where((p) => p.id == id).firstOrNull;
    if (id != null && old == null) {
      throw StateError('This profile no longer exists.');
    }
    if (id == null && profiles.length >= 100) {
      throw StateError('Local storage supports up to 100 profiles.');
    }
    final now = DateTime.now().toUtc();
    await repository.putProfile(
      PaymentProfile(
        id: id ?? _id(),
        label: name,
        link: link,
        notes: PaymentPolicy.text(notes, 'notes', max: 1000, required: false),
        createdAtUtc: old?.createdAtUtc ?? now,
        updatedAtUtc: now,
      ),
    );
  });
  Future<void> saveTemplate({
    String? id,
    required String profileId,
    required String label,
    bool updateLink = false,
  }) => _write(() async {
    final profile = profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      throw StateError('Choose an existing payment profile.');
    }
    final old = templates.where((t) => t.id == id).firstOrNull;
    if (id != null && old == null) {
      throw StateError('This template no longer exists.');
    }
    if (id == null && templates.length >= 1000) {
      throw StateError('Local storage supports up to 1,000 templates.');
    }
    final now = DateTime.now().toUtc();
    await repository.putTemplate(
      PaymentTemplate(
        id: id ?? _id(),
        profileId: profileId,
        label: PaymentPolicy.text(label, 'a template name'),
        link: old != null && old.profileId == profileId && !updateLink
            ? old.link
            : profile.link,
        state: PaymentTemplateState.draft,
        createdAtUtc: old?.createdAtUtc ?? now,
        updatedAtUtc: now,
      ),
    );
  });
  PaymentTemplate _template(String id) => templates.firstWhere(
    (t) => t.id == id,
    orElse: () => throw StateError('This template no longer exists.'),
  );
  Future<void> duplicate(String id) => _write(() async {
    if (templates.length >= 1000) {
      throw StateError('Local storage supports up to 1,000 templates.');
    }
    final t = _template(id);
    final now = DateTime.now().toUtc();
    await repository.putTemplate(
      PaymentTemplate(
        id: _id(),
        profileId: t.profileId,
        label: t.label.length <= 73 ? '${t.label} (copy)' : t.label,
        link: t.link,
        state: PaymentTemplateState.draft,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
  });
  Future<void> setStateFor(String id, PaymentTemplateState state) =>
      _write(() async {
        final t = _template(id);
        if (state == PaymentTemplateState.ready) {
          if (t.state == PaymentTemplateState.archived) {
            throw StateError('Restore the template to Draft first.');
          }
          await PaymentQr.render(t, sample: sample);
          _requireManage(); // Ownership may change while rendering.
        }
        await repository.putTemplate(
          PaymentTemplate(
            id: t.id,
            profileId: t.profileId,
            label: t.label,
            link: t.link,
            state: state,
            createdAtUtc: t.createdAtUtc,
            updatedAtUtc: DateTime.now().toUtc(),
          ),
        );
      });
  Future<PaymentQrArtifact> exportArtifact(String id) async {
    final t = _template(id);
    if (!canExport || t.state != PaymentTemplateState.ready) {
      throw StateError(
        'Export requires Payments ownership and a Ready template.',
      );
    }
    final result = await PaymentQr.render(t);
    final current = _template(id);
    if (!canExport ||
        current.state != PaymentTemplateState.ready ||
        current.link != t.link ||
        current.label != t.label) {
      throw StateError(
        'The template or Payments access changed. Review it again.',
      );
    }
    return result;
  }

  Future<void> deleteProfile(String id) =>
      _write(() => repository.deleteProfile(id), managed: false);
  Future<void> deleteTemplate(String id) =>
      _write(() => repository.deleteTemplate(id), managed: false);
  Future<void> clear() => _write(repository.clear, managed: false);
  String exportRecords() {
    if (sample) throw StateError('Sample records are not exported.');
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'dali_payments_workspace',
      'version': 1,
      'profiles': [
        for (final p in profiles)
          {
            'id': p.id,
            'label': p.label,
            'link': p.link,
            'notes': p.notes,
            'createdUtc': p.createdAtUtc.toIso8601String(),
            'updatedUtc': p.updatedAtUtc.toIso8601String(),
          },
      ],
      'templates': [
        for (final t in templates)
          {
            'id': t.id,
            'profileId': t.profileId,
            'label': t.label,
            'link': t.link,
            'state': t.state.name,
            'createdUtc': t.createdAtUtc.toIso8601String(),
            'updatedUtc': t.updatedAtUtc.toIso8601String(),
          },
      ],
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    await repository.close();
    dispose();
  }

  static Future<PaymentsController> demo(
    PaymentsEntitlement entitlement,
  ) async {
    final c = PaymentsController(
      repository: LocalPaymentsRepository(
        PaymentsDatabase(NativeDatabase.memory()),
      ),
      entitlement: entitlement,
      sample: true,
    );
    try {
      await c.refresh();
      await c.saveProfile(
        label: 'Sample shop',
        link: PaymentPolicy.sampleLink,
        notes: 'Example data only.',
      );
      await c.saveTemplate(
        profileId: c.profiles.single.id,
        label: 'Sample payment card',
      );
      return c;
    } on Object {
      await c.close();
      rethrow;
    }
  }
}
