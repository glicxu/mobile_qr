import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/saved_page.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows saved QRs independently of history', (tester) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    await repository.save(
      QrHistoryItem(
        id: 'saved-only',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'raw useful value',
        displayHost: null,
        title: 'Gym pass',
        note: 'Front desk',
        isInHistory: false,
        savedAtUtc: DateTime.now().toUtc(),
        source: QrActivitySource.camera,
        createdAtUtc: DateTime.now().toUtc(),
      ),
    );
    final controller = HistoryController(repository, _DisabledSettings());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SavedPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Codes'), findsOneWidget);
    expect(find.text('Gym pass'), findsOneWidget);
    expect(find.text('Front desk'), findsOneWidget);
    expect(controller.items, isEmpty);
  });

  testWidgets('displays verification code in saved QR detail sheet', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    await repository.save(
      QrHistoryItem(
        id: 'saved-verified',
        activityKind: QrActivityKind.created,
        payloadKind: QrPayloadKind.url,
        rawPayload: 'https://example.com/login',
        displayHost: 'example.com',
        title: 'Login page',
        verificationCode: 'XIH-000',
        registrableDomain: 'example.com',
        isInHistory: false,
        savedAtUtc: DateTime.now().toUtc(),
        source: QrActivitySource.manual,
        createdAtUtc: DateTime.now().toUtc(),
      ),
    );
    final controller = HistoryController(repository, _DisabledSettings());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SavedPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login page'));
    await tester.pumpAndSettle();

    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('XIH-000'), findsOneWidget);
    expect(find.text('example.com'), findsWidgets);
    expect(find.byTooltip('Copy verification code'), findsOneWidget);
  });

  testWidgets('labels a saved barcode without fabricating QR artwork', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    await repository.save(
      QrHistoryItem(
        id: 'saved-barcode',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: '012345678905',
        displayHost: null,
        codeFormat: ScannedCodeFormat.upcA,
        isInHistory: false,
        savedAtUtc: DateTime.now().toUtc(),
        source: QrActivitySource.sharedImage,
        createdAtUtc: DateTime.now().toUtc(),
      ),
    );
    final controller = HistoryController(repository, _DisabledSettings());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SavedPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('012345678905'));
    await tester.pumpAndSettle();

    expect(find.text('Saved UPC-A'), findsOneWidget);
    expect(find.text('UPC-A · Shared image'), findsOneWidget);
    expect(find.text('Copy QR image'), findsNothing);
  });
}

final class _DisabledSettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => false;

  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}
