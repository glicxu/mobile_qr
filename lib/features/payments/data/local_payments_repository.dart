import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';

import '../domain/payment_workspace.dart';
import 'payments_database.dart';

final class LocalPaymentsRepository implements PaymentsRepository {
  LocalPaymentsRepository(this.database);
  final PaymentsDatabase database;
  static Future<LocalPaymentsRepository> open() async {
    final path = await const MethodChannel(
      'dali_qr/local_storage',
    ).invokeMethod<String>('paymentsDatabasePath');
    if (path == null || path.isEmpty || !File(path).isAbsolute) {
      throw StateError('Protected payments storage is unavailable.');
    }
    final repository = LocalPaymentsRepository(
      PaymentsDatabase(NativeDatabase(File(path))),
    );
    try {
      await repository.profiles();
      return repository;
    } on Object {
      await repository.close();
      rethrow;
    }
  }

  static DateTime _date(int n) =>
      DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
  @override
  Future<List<PaymentProfile>> profiles() async =>
      (await database
              .customSelect(
                'SELECT * FROM payment_profiles ORDER BY updated_utc DESC, id',
              )
              .get())
          .map(
            (r) => PaymentProfile(
              id: r.read('id'),
              label: r.read('label'),
              link: r.read('link'),
              notes: r.read('notes'),
              createdAtUtc: _date(r.read('created_utc')),
              updatedAtUtc: _date(r.read('updated_utc')),
            ),
          )
          .toList();
  @override
  Future<List<PaymentTemplate>> templates() async =>
      (await database
              .customSelect(
                'SELECT * FROM payment_templates ORDER BY updated_utc DESC, id',
              )
              .get())
          .map(
            (r) => PaymentTemplate(
              id: r.read('id'),
              profileId: r.read('profile_id'),
              label: r.read('label'),
              link: r.read('link'),
              state: PaymentTemplateState.values.byName(r.read('state')),
              createdAtUtc: _date(r.read('created_utc')),
              updatedAtUtc: _date(r.read('updated_utc')),
            ),
          )
          .toList();
  @override
  Future<void> putProfile(PaymentProfile p) async {
    final label = PaymentPolicy.text(p.label, 'a profile name');
    PaymentPolicy.link(p.link);
    final notes = PaymentPolicy.text(
      p.notes,
      'notes',
      max: 1000,
      required: false,
    );
    await database.customStatement(
      '''INSERT INTO payment_profiles VALUES (?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET label=excluded.label, link=excluded.link,
      notes=excluded.notes, updated_utc=excluded.updated_utc''',
      [
        p.id,
        label,
        p.link,
        notes,
        p.createdAtUtc.millisecondsSinceEpoch,
        p.updatedAtUtc.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> putTemplate(PaymentTemplate t) async {
    final label = PaymentPolicy.text(t.label, 'a template name');
    PaymentPolicy.link(t.link);
    await database.customStatement(
      '''INSERT INTO payment_templates VALUES (?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET profile_id=excluded.profile_id, label=excluded.label,
      link=excluded.link, state=excluded.state, updated_utc=excluded.updated_utc''',
      [
        t.id,
        t.profileId,
        label,
        t.link,
        t.state.name,
        t.createdAtUtc.millisecondsSinceEpoch,
        t.updatedAtUtc.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> deleteProfile(String id) => database.transaction(() async {
    final matches = await database
        .customSelect(
          'SELECT id FROM payment_templates WHERE profile_id=? LIMIT 1',
          variables: [Variable(id)],
        )
        .get();
    if (matches.isNotEmpty) {
      throw StateError(
        'Delete this profile’s templates first, including archived templates.',
      );
    }
    await database.customStatement('DELETE FROM payment_profiles WHERE id=?', [
      id,
    ]);
  });
  @override
  Future<void> deleteTemplate(String id) => database.customStatement(
    'DELETE FROM payment_templates WHERE id=?',
    [id],
  );
  @override
  Future<void> clear() => database.transaction(() async {
    await database.customStatement('DELETE FROM payment_templates');
    await database.customStatement('DELETE FROM payment_profiles');
  });
  @override
  Future<void> close() => database.close();
}
