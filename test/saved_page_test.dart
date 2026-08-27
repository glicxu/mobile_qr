import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/saved_page.dart';
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

    expect(find.text('Saved QRs'), findsOneWidget);
    expect(find.text('Gym pass'), findsOneWidget);
    expect(find.text('Front desk'), findsOneWidget);
    expect(controller.items, isEmpty);
  });
}

final class _DisabledSettings implements HistorySettingsStore {
  @override
  Future<bool> historyEnabled() async => false;

  @override
  Future<HistoryRetention> retention() async => HistoryRetention.forever;

  @override
  Future<void> setHistoryEnabled(bool enabled) async {}

  @override
  Future<void> setRetention(HistoryRetention retention) async {}
}
