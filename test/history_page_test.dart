import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/history_page.dart';
import 'package:dali_qr/features/monetization/application/customization_entitlement.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('groups history by local date and exposes delete buttons', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    final now = DateTime(2026, 9, 1, 0, 30);
    await repository.save(_item('today', now.toUtc()));
    await repository.save(
      _item('yesterday', now.subtract(const Duration(hours: 1)).toUtc()),
    );
    final controller = HistoryController(
      repository,
      _EnabledHistorySettings(),
      now: () => now,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: HistoryPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byTooltip('Delete history item'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete history item').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete history item?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete history item'), findsOneWidget);
  });

  testWidgets('uses a custom title in the list and saves notes', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    await repository.save(_item('raw payload', DateTime.now().toUtc()));
    final controller = HistoryController(repository, _EnabledHistorySettings());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: HistoryPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('raw payload'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Lunch menu',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note'),
      'Try the special',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Lunch menu'), findsOneWidget);
    expect(find.text('raw payload'), findsNothing);
    final saved = controller.items.single;
    expect(saved.title, 'Lunch menu');
    expect(saved.note, 'Try the special');
  });

  testWidgets('warns that a saved QR remains when removed from history', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    await repository.save(
      QrHistoryItem(
        id: 'saved',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'saved payload',
        displayHost: null,
        savedAtUtc: DateTime.now().toUtc(),
        source: QrActivitySource.camera,
        createdAtUtc: DateTime.now().toUtc(),
      ),
    );
    final controller = HistoryController(repository, _EnabledHistorySettings());
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HistoryPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete history item'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'This QR is marked as Saved. Deleting it will remove it permanently.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'filters by saved and toggles bookmark state from tile and sheet',
    (tester) async {
      final repository = DriftQrHistoryRepository(
        HistoryDatabase.forTesting(NativeDatabase.memory()),
      );
      final now = DateTime(2026, 9, 1, 12, 0);
      await repository.save(_item('item-1', now.toUtc()));
      await repository.save(
        QrHistoryItem(
          id: 'item-2',
          activityKind: QrActivityKind.created,
          payloadKind: QrPayloadKind.text,
          rawPayload: 'item-2-saved',
          displayHost: null,
          source: QrActivitySource.manual,
          createdAtUtc: now.toUtc(),
          savedAtUtc: now.toUtc(),
        ),
      );
      final controller = HistoryController(
        repository,
        _EnabledHistorySettings(),
        now: () => now,
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: HistoryPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Both items visible initially under 'All'
      expect(find.text('item-1'), findsOneWidget);
      expect(find.text('item-2-saved'), findsOneWidget);

      // Switch to 'Saved'
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      expect(find.text('item-1'), findsNothing);
      expect(find.text('item-2-saved'), findsOneWidget);

      // Switch back to 'All'
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('item-1'), findsOneWidget);
      expect(find.text('item-2-saved'), findsOneWidget);

      // Toggle save on item-1 via tile bookmark button
      await tester.tap(find.byTooltip('Save QR'));
      await tester.pumpAndSettle();

      // Now switch to 'Saved' again - item-1 is now saved!
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      expect(find.text('item-1'), findsOneWidget);
      expect(find.text('item-2-saved'), findsOneWidget);

      // Open detail sheet for item-2-saved and unsave
      await tester.tap(find.text('item-2-saved'));
      await tester.pumpAndSettle();
      expect(find.text('Unsave'), findsOneWidget);
      await tester.tap(find.text('Unsave'));
      await tester.pumpAndSettle();

      // item-2-saved is now unsaved, so in 'Saved' view only item-1 remains
      expect(find.text('item-1'), findsOneWidget);
      expect(find.text('item-2-saved'), findsNothing);
    },
  );

  testWidgets('free history keeps older entries and offers an unlock', (
    tester,
  ) async {
    final repository = DriftQrHistoryRepository(
      HistoryDatabase.forTesting(NativeDatabase.memory()),
    );
    final now = DateTime.utc(2026, 9, 1, 12);
    await repository.save(
      _item('older entry', now.subtract(const Duration(days: 8))),
    );
    final controller = HistoryController(
      repository,
      _EnabledHistorySettings(),
      now: () => now,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: controller,
          customizationEntitlement: Future.value(_LockedEntitlement()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.lockedItemCount, 1);
    expect(find.text('1 older QR code is locked'), findsOneWidget);
    expect(find.textContaining('Nothing was deleted.'), findsOneWidget);

    await tester.tap(find.text('Unlock history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Unlock your full history'), findsOneWidget);
    expect(find.text('Unlock lifetime customization'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);

    Navigator.of(tester.element(find.text('Unlock your full history'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

QrHistoryItem _item(String id, DateTime createdAtUtc) {
  return QrHistoryItem(
    id: id,
    activityKind: QrActivityKind.created,
    payloadKind: QrPayloadKind.text,
    rawPayload: id,
    displayHost: null,
    source: QrActivitySource.manual,
    createdAtUtc: createdAtUtc,
  );
}

final class _EnabledHistorySettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => true;

  @override
  Future<void> setHistoryEnabled(bool enabled) async {}
}

final class _LockedEntitlement extends CustomizationEntitlement {
  @override
  bool get isBusy => false;

  @override
  bool get isStoreAvailable => true;

  @override
  bool get isUnlocked => false;

  @override
  String? get message => null;

  @override
  String? get price => r'$3.99';

  @override
  Future<void> refresh() async {}

  @override
  Future<void> purchase() async {}

  @override
  Future<void> restore() async {}
}
