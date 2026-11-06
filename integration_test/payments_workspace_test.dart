import 'dart:convert';
import 'dart:io';

import 'package:dali_qr/features/payments/application/payments_controller.dart';
import 'package:dali_qr/features/payments/application/payments_entitlement.dart';
import 'package:dali_qr/features/payments/data/local_payments_repository.dart';
import 'package:dali_qr/features/payments/domain/payment_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/payments_test_access.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated payments persistence and native image round trips', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('DALI_SCANNER_QA_BUILD'), isTrue);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    const storage = MethodChannel('dali_qr/local_storage');
    final path = (await storage.invokeMethod<String>('paymentsDatabasePath'))!;
    final batch = await storage.invokeMethod<String>('batchDatabasePath');
    expect(path, isNot(batch));
    expect(path, contains('/no_backup/dali_payments/'));
    final access = TestPaymentsAccess(); // QA-only; never a production unlock.
    var c = PaymentsController(
      repository: await LocalPaymentsRepository.open(),
      entitlement: access,
    );
    final scanner = MobileScannerController(autoStart: false);
    final temporary = await getTemporaryDirectory();
    try {
      await c.refresh();
      expect(c.profiles, isEmpty);
      const original =
          'https://checkout.example.com/Invoice%2fA?ref=0001%2B02#Review';
      await c.saveProfile(label: 'QA shop', link: original);
      final profileId = c.profiles.single.id;
      await c.saveTemplate(profileId: profileId, label: 'QA invoice');
      final templateId = c.templates.single.id;
      await c.saveProfile(
        id: profileId,
        label: 'QA shop updated',
        link: 'https://checkout.example.com/new',
      );
      await c.saveTemplate(
        id: templateId,
        profileId: profileId,
        label: 'Renamed invoice',
      );
      expect(c.templates.single.link, original);
      await c.close();
      c = PaymentsController(
        repository: await LocalPaymentsRepository.open(),
        entitlement: access,
      );
      await c.refresh();
      expect(c.templates.single.link, original);
      await c.setStateFor(templateId, PaymentTemplateState.ready);
      final artifact = await c.exportArtifact(templateId);
      for (final entry in {
        'qr': artifact.qrPng,
        'card': artifact.cardPng,
      }.entries) {
        final file = File('${temporary.path}/payments_qa_${entry.key}.png');
        try {
          await file.writeAsBytes(entry.value);
          // Native ML Kit only: do not let fallback hide native image failures.
          final capture = await scanner.analyzeImage(
            file.path,
            formats: [BarcodeFormat.qrCode],
          );
          expect(capture?.barcodes.any((b) => b.rawValue == original), isTrue);
        } finally {
          if (await file.exists()) await file.delete();
        }
      }
      await File(
        '${temporary.path}/payments_qa_preview.png',
      ).writeAsBytes(artifact.cardPng);
      access.change(PaymentsAccessState.locked);
      await expectLater(c.exportArtifact(templateId), throwsStateError);
      expect((jsonDecode(c.exportRecords()) as Map)['templates'], hasLength(1));
      await c.clear();
      expect(c.profiles, isEmpty);
      final unconfigured = UnconfiguredPaymentsEntitlement();
      expect(unconfigured.canPurchase, isFalse);
      expect(unconfigured.canRestore, isFalse);
      final sample = await PaymentsController.demo(unconfigured);
      expect(sample.canExport, isFalse);
      await sample.close();
      unconfigured.dispose();
      debugPrint(
        'PAYMENTS_QA ${jsonEncode({'persistence': true, 'snapshotPreserved': true, 'nativeQr': true, 'nativeCard': true, 'revokedExportBlocked': true, 'recordExportAndDeletion': true, 'sampleIsolated': true, 'liveBilling': false, 'result': 'passed'})}',
      );
    } finally {
      await scanner.dispose();
      await c.close();
      access.dispose();
    }
  });
}
