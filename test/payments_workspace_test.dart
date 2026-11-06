import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/payments/application/payments_controller.dart';
import 'package:dali_qr/features/payments/application/payments_entitlement.dart';
import 'package:dali_qr/features/payments/application/payment_qr.dart';
import 'package:dali_qr/features/payments/data/local_payments_repository.dart';
import 'package:dali_qr/features/payments/data/payments_database.dart';
import 'package:dali_qr/features/payments/domain/payment_workspace.dart';
import 'package:dali_qr/features/create/application/qr_png_validator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/payments_test_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only bounded HTTPS links without embedded credentials are accepted literally',
    () {
      const link =
          'https://checkout.example.com/P%2fA?token=X%2By&amount=12.30#Review';
      expect(PaymentPolicy.link(link), link);
      for (final raw in [
        'http://pay.example/a',
        'https://user:pass@pay.example/a',
        'https://localhost/a',
        'https://localhost./a',
        'https://shop.local./a',
        'https://127.0.0.1/a',
        'https://[::1]/a',
        'https://pay.example:444/a',
        ' https://pay.example/a',
        'https://pay.example/a\n',
      ]) {
        expect(() => PaymentPolicy.link(raw), throwsFormatException);
      }
    },
  );
  test(
    'unconfigured store cannot purchase, restore or infer ownership',
    () async {
      final access = UnconfiguredPaymentsEntitlement();
      addTearDown(access.dispose);
      expect(access.isOwned, isFalse);
      expect(access.canPurchase, isFalse);
      expect(access.localizedPrice, isNull);
      await expectLater(access.purchase(), throwsStateError);
      await expectLater(access.restore(), throwsStateError);
    },
  );
  testWidgets(
    'snapshots, validation, duplicate and revocation preserve original records',
    (tester) async {
      final access = TestPaymentsAccess();
      final c = PaymentsController(
        repository: LocalPaymentsRepository(
          PaymentsDatabase(NativeDatabase.memory()),
        ),
        entitlement: access,
      );
      await tester.runAsync(() async {
        await c.refresh();
        const original = 'https://checkout.example.com/first?ref=001%2B02';
        await c.saveProfile(label: 'Shop', link: original);
        final profile = c.profiles.single;
        await c.saveTemplate(profileId: profile.id, label: 'Invoice 001');
        final t = c.templates.single;
        await c.saveProfile(
          id: profile.id,
          label: 'Updated shop',
          link: 'https://checkout.example.com/second',
        );
        expect(c.templates.single.link, original);
        await c.saveTemplate(
          id: t.id,
          profileId: profile.id,
          label: 'Renamed invoice',
        );
        expect(c.templates.single.link, original);
        await c.duplicate(t.id);
        expect(c.templates.every((t) => t.link == original), isTrue);
        await expectLater(c.deleteProfile(profile.id), throwsStateError);
      });
      final id = c.templates.first.id;
      await tester.runAsync(
        () => c.setStateFor(id, PaymentTemplateState.ready),
      );
      final artifact = (await tester.runAsync(() => c.exportArtifact(id)))!;
      expect(
        const QrPngValidator().containsExactPayload(
          artifact.qrPng,
          artifact.link,
        ),
        isTrue,
      );
      expect(
        const QrPngValidator().containsExactPayload(
          artifact.cardPng,
          artifact.link,
        ),
        isTrue,
      );
      await tester.runAsync(() async {
        await c.setStateFor(id, PaymentTemplateState.archived);
        await expectLater(c.exportArtifact(id), throwsStateError);
        await c.setStateFor(id, PaymentTemplateState.draft);
        await expectLater(c.exportArtifact(id), throwsStateError);
        access.change(PaymentsAccessState.locked);
        await expectLater(
          c.saveProfile(label: 'Blocked', link: 'https://pay.example/new'),
          throwsStateError,
        );
        final data = jsonDecode(c.exportRecords()) as Map;
        expect((data['templates'] as List).length, 2);
        expect(
          (data['templates'] as List).every((t) => t['link'] == artifact.link),
          isTrue,
        );
        await c.clear();
        expect(c.profiles, isEmpty);
        expect(c.templates, isEmpty);
        await c.close();
        access.dispose();
      });
    },
  );
  test('template link refresh requires an explicit opt-in', () async {
    final access = TestPaymentsAccess();
    final c = PaymentsController(
      repository: LocalPaymentsRepository(
        PaymentsDatabase(NativeDatabase.memory()),
      ),
      entitlement: access,
    );
    try {
      await c.refresh();
      await c.saveProfile(
        label: 'Shop',
        link: 'https://checkout.example.com/first',
      );
      final p = c.profiles.single.id;
      await c.saveTemplate(profileId: p, label: 'Invoice');
      final t = c.templates.single.id;
      await c.saveProfile(
        id: p,
        label: 'Shop',
        link: 'https://checkout.example.com/second',
      );
      await c.saveTemplate(id: t, profileId: p, label: 'Renamed');
      expect(c.templates.single.link, 'https://checkout.example.com/first');
      await c.saveTemplate(
        id: t,
        profileId: p,
        label: 'Updated',
        updateLink: true,
      );
      expect(c.templates.single.link, 'https://checkout.example.com/second');
      expect(c.templates.single.state, PaymentTemplateState.draft);
    } finally {
      await c.close();
      access.dispose();
    }
  });
  testWidgets('sample workspace never exports or accepts a real link', (
    tester,
  ) async {
    final access = UnconfiguredPaymentsEntitlement();
    final c = (await tester.runAsync(() => PaymentsController.demo(access)))!;
    expect(c.canManage, isTrue);
    expect(c.canExport, isFalse);
    await expectLater(
      c.exportArtifact(c.templates.single.id),
      throwsStateError,
    );
    expect(c.exportRecords, throwsStateError);
    await tester.runAsync(() async {
      await expectLater(
        c.saveProfile(label: 'Real', link: 'https://checkout.example.com/real'),
        throwsStateError,
      );
      await c.close();
      access.dispose();
    });
  });
  test(
    'file-backed workspace survives close/reopen; foreign keys prevent dangling templates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dali_payments_test_',
      );
      final file = File('${directory.path}/payments.sqlite');
      final now = DateTime.utc(2026, 10, 30);
      var repo = LocalPaymentsRepository(
        PaymentsDatabase(NativeDatabase(file)),
      );
      const link = 'https://checkout.example.com/invoice?ref=0001';
      await repo.putProfile(
        PaymentProfile(
          id: 'p',
          label: 'Shop',
          link: link,
          notes: 'Private note',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
      await repo.putTemplate(
        PaymentTemplate(
          id: 't',
          profileId: 'p',
          label: 'Invoice',
          link: link,
          state: PaymentTemplateState.draft,
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
      await repo.close();
      repo = LocalPaymentsRepository(PaymentsDatabase(NativeDatabase(file)));
      expect((await repo.profiles()).single.notes, 'Private note');
      expect((await repo.templates()).single.link, link);
      await expectLater(repo.deleteProfile('p'), throwsStateError);
      await repo.deleteTemplate('t');
      await repo.deleteProfile('p');
      expect(await repo.profiles(), isEmpty);
      await repo.close();
      for (final name in [
        'payments.sqlite',
        'payments.sqlite-wal',
        'payments.sqlite-shm',
      ]) {
        final dbFile = File('${directory.path}/$name');
        if (await dbFile.exists()) await dbFile.delete();
      }
      await directory.delete();
    },
  );
  testWidgets('payment card preserves Unicode labels and exact destination', (
    tester,
  ) async {
    const link = 'https://checkout.example.com/pay?note=A%2BB%20%26%20100%25';
    final now = DateTime.utc(2026);
    final artifact = (await tester.runAsync(
      () => PaymentQr.render(
        PaymentTemplate(
          id: 't',
          profileId: 'p',
          label: 'Café · 店舗',
          link: link,
          state: PaymentTemplateState.ready,
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      ),
    ))!;
    expect(
      const QrPngValidator().containsExactPayload(artifact.cardPng, link),
      isTrue,
    );
    final dir = Directory('.dart_tool/payments-qa')
      ..createSync(recursive: true);
    File('${dir.path}/payment-card.png').writeAsBytesSync(artifact.cardPng);
    File('${dir.path}/payment-qr.png').writeAsBytesSync(artifact.qrPng);
    File(
      '${dir.path}/manifest.json',
    ).writeAsStringSync(jsonEncode({'link': link}));
  });
}
