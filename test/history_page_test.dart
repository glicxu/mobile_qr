import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:dali_qr/features/history/presentation/history_page.dart';
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
    final now = DateTime.now();
    await repository.save(_item('today', now.toUtc()));
    await repository.save(
      _item('yesterday', now.subtract(const Duration(days: 1)).toUtc()),
    );
    final controller = HistoryController(repository, _EnabledHistorySettings());
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
  Future<HistoryRetention> retention() async => HistoryRetention.forever;

  @override
  Future<void> setHistoryEnabled(bool enabled) async {}

  @override
  Future<void> setRetention(HistoryRetention retention) async {}
}
