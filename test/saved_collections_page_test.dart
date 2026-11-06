import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/saved_page.dart';
import 'package:dali_qr/features/scan/domain/scanned_code.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => registerCollectionsTests();

void registerCollectionsTests() {
  testWidgets(
    'create, file, tag-search and delete a collection without deleting Saved codes',
    (tester) async {
      final repository = DriftQrHistoryRepository(
        HistoryDatabase.forTesting(NativeDatabase.memory()),
      );
      final now = DateTime.now().toUtc();
      await repository.save(
        QrHistoryItem(
          id: 'a',
          activityKind: QrActivityKind.scanned,
          payloadKind: QrPayloadKind.text,
          rawPayload: 'code-a',
          displayHost: null,
          title: 'Code A',
          codeFormat: ScannedCodeFormat.code128,
          source: QrActivitySource.camera,
          isInHistory: false,
          savedAtUtc: now,
          createdAtUtc: now,
        ),
      );
      final controller = HistoryController(repository, _Settings());
      await controller.initialize();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: SavedPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Collection name'),
        'Trip',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleDatabase(tester);
      expect(find.widgetWithText(ChoiceChip, 'Trip'), findsOneWidget);
      await tester.tap(find.text('Code A'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Trip'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tags'),
        'Travel, OFFICE',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleDatabase(tester);
      expect(controller.organization.tags['a'], ['OFFICE', 'Travel']);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unfiled'));
      await tester.pumpAndSettle();
      expect(find.text('Code A'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trip'));
      await tester.pumpAndSettle();
      expect(find.text('Code A'), findsOneWidget);
      await tester.enterText(find.byType(SearchBar), 'travel');
      await tester.pumpAndSettle();
      expect(find.text('Code A'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete Trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleDatabase(tester);
      expect(controller.organization.collections, isEmpty);
      expect(controller.savedItems.single.rawPayload, 'code-a');
      expect(controller.organization.tags['a'], ['OFFICE', 'Travel']);
    },
  );

  for (final malformed in [false, true]) {
    testWidgets(
      'Saved list and search hide Wi-Fi credentials, malformed=$malformed',
      (tester) async {
        final repository = DriftQrHistoryRepository(
          HistoryDatabase.forTesting(NativeDatabase.memory()),
        );
        final now = DateTime.now().toUtc();
        await repository.save(
          QrHistoryItem(
            id: 'wifi',
            activityKind: QrActivityKind.scanned,
            payloadKind: QrPayloadKind.text,
            rawPayload: malformed
                ? 'WIFI:S:Guest;S:duplicate;P:private-password;;'
                : 'WIFI:S:Guest;P:private-password;;',
            displayHost: null,
            source: QrActivitySource.camera,
            savedAtUtc: now,
            createdAtUtc: now,
          ),
        );
        final controller = HistoryController(repository, _Settings());
        await controller.initialize();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(home: SavedPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('private-password'), findsNothing);
        expect(find.textContaining('Sensitive content'), findsOneWidget);
        await tester.enterText(find.byType(SearchBar), 'private-password');
        await tester.pumpAndSettle();
        expect(find.textContaining('Sensitive content'), findsNothing);
      },
    );
  }
}

Future<void> settleDatabase(WidgetTester tester) async {
  for (var index = 0; index < 4; index++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
}

final class _Settings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => true;
  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}
