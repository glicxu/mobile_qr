import 'package:dali_qr/features/history/application/history_controller.dart';
import 'package:dali_qr/features/history/data/drift_qr_history_repository.dart';
import 'package:dali_qr/features/history/data/history_database.dart';
import 'package:dali_qr/features/history/domain/qr_history.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  late HistoryDatabase database;
  late DriftQrHistoryRepository repository;
  late _MemoryHistorySettings settings;
  late HistoryController controller;

  setUp(() async {
    database = HistoryDatabase.forTesting(NativeDatabase.memory());
    repository = DriftQrHistoryRepository(database);
    settings = _MemoryHistorySettings();
    controller = HistoryController(
      repository,
      settings,
      now: () => DateTime.utc(2026, 8, 20, 12),
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('history is off by default and does not save activity', () async {
    await controller.recordCreated(
      payload: 'https://example.com/',
      verificationCode: 'ABC-123',
      registrableDomain: 'example.com',
      qrPngBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(controller.enabled, isFalse);
    expect(await repository.watchRecent().first, isEmpty);
  });

  test('opt-in saves created and scanned values locally', () async {
    await controller.enable();
    await controller.recordCreated(
      payload: 'https://example.com/created',
      verificationCode: 'ABC-123',
      registrableDomain: 'example.com',
      qrPngBytes: Uint8List.fromList([1, 2, 3]),
    );
    await controller.recordScanned(
      payload: 'plain scanned text',
      qrPngBytes: Uint8List.fromList([4, 5, 6]),
    );

    final items = await repository.watchRecent().first;
    expect(items, hasLength(2));
    final scanned = items.singleWhere(
      (item) => item.activityKind == QrActivityKind.scanned,
    );
    final created = items.singleWhere(
      (item) => item.activityKind == QrActivityKind.created,
    );
    expect(scanned.payloadKind, QrPayloadKind.text);
    expect(created.displayHost, 'example.com');
    expect(created.verificationCode, 'ABC-123');
    expect(created.registrableDomain, 'example.com');
    expect(created.qrPngBytes, [1, 2, 3]);
    expect(scanned.qrPngBytes, [4, 5, 6]);
  });

  test('free history locks expired entries without deleting them', () async {
    await repository.save(
      QrHistoryItem(
        id: 'old',
        activityKind: QrActivityKind.created,
        payloadKind: QrPayloadKind.url,
        rawPayload: 'https://old.example/',
        displayHost: 'old.example',
        source: QrActivitySource.manual,
        createdAtUtc: DateTime.utc(2026, 8, 1),
      ),
    );
    await controller.enable();

    expect(await repository.watchRecent().first, hasLength(1));
    expect(controller.items, isEmpty);
    expect(controller.lockedItemCount, 1);
  });

  test('free history includes an entry exactly one week old', () async {
    await repository.save(
      QrHistoryItem(
        id: 'boundary',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'boundary scan',
        displayHost: null,
        source: QrActivitySource.camera,
        createdAtUtc: DateTime.utc(2026, 8, 13, 12),
      ),
    );

    await controller.enable();
    await pumpEventQueue();

    expect(controller.items.single.id, 'boundary');
    expect(controller.lockedItemCount, 0);
  });

  test('unlocking reveals older history that was kept on device', () async {
    await repository.save(
      QrHistoryItem(
        id: 'old',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'old scan',
        displayHost: null,
        source: QrActivitySource.camera,
        createdAtUtc: DateTime.utc(2026, 8, 1),
      ),
    );
    await controller.enable();
    await pumpEventQueue();

    expect(controller.items, isEmpty);
    expect(controller.lockedItemCount, 1);

    await controller.setExtendedHistoryUnlocked(true);

    expect(controller.items.single.rawPayload, 'old scan');
    expect(controller.lockedItemCount, 0);
  });

  test('unlocked history can access older entries', () async {
    await repository.save(
      QrHistoryItem(
        id: 'week-old',
        activityKind: QrActivityKind.scanned,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'week old scan',
        displayHost: null,
        source: QrActivitySource.camera,
        createdAtUtc: DateTime.utc(2026, 8, 13, 12),
      ),
    );

    await controller.setExtendedHistoryUnlocked(true);
    await controller.enable();
    await pumpEventQueue();

    expect(controller.lockedItemCount, 0);
    expect(controller.items, hasLength(1));
    expect(await repository.watchRecent().first, hasLength(1));
  });

  test('scanned URLs retain verification and QR sharing data', () async {
    await controller.enable();
    await controller.recordScanned(
      payload: 'https://example.com/scanned',
      verificationCode: 'XYZ-789',
      registrableDomain: 'example.com',
      qrPngBytes: Uint8List.fromList([7, 8, 9]),
    );

    final item = (await repository.watchRecent().first).single;
    expect(item.activityKind, QrActivityKind.scanned);
    expect(item.payloadKind, QrPayloadKind.url);
    expect(item.verificationCode, 'XYZ-789');
    expect(item.registrableDomain, 'example.com');
    expect(item.qrPngBytes, [7, 8, 9]);
  });

  test('title and note can be added, changed, and cleared', () async {
    await controller.enable();
    await controller.recordScanned(payload: 'plain scanned text');
    final id = (await repository.watchRecent().first).single.id;

    await controller.updateMetadata(
      id,
      title: '  Grocery receipt  ',
      note: '  Paid in cash  ',
    );

    var item = (await repository.watchRecent().first).single;
    expect(item.title, 'Grocery receipt');
    expect(item.note, 'Paid in cash');

    await controller.updateMetadata(id, title: ' ', note: '');
    item = (await repository.watchRecent().first).single;
    expect(item.title, isNull);
    expect(item.note, isNull);
  });

  test('turning history off can preserve or delete existing rows', () async {
    await controller.enable();
    await controller.recordCreated(
      payload: 'https://example.com/',
      verificationCode: 'ABC-123',
      registrableDomain: 'example.com',
      qrPngBytes: Uint8List.fromList([1, 2, 3]),
    );
    await controller.disable(deleteExisting: false);

    expect(await repository.watchRecent().first, hasLength(1));

    await controller.enable();
    await controller.disable(deleteExisting: true);
    expect(await repository.watchRecent().first, isEmpty);
  });

  test('saving works while history is off', () async {
    await controller.savePayload(
      payload: 'useful value',
      activityKind: QrActivityKind.scanned,
      source: QrActivitySource.camera,
    );

    final item = (await repository.watchRecent().first).single;
    expect(item.isInHistory, isFalse);
    expect(item.savedAtUtc, isNotNull);
    expect(controller.items, isEmpty);
    expect(controller.savedItems.single.rawPayload, 'useful value');
  });

  test('removing a saved item from history preserves it in Saved', () async {
    await controller.enable();
    await controller.recordScanned(payload: 'saved scan');
    final item = (await repository.watchRecent().first).single;
    await controller.save(item.id);
    await controller.delete(item.id);

    final remaining = (await repository.watchRecent().first).single;
    expect(remaining.isInHistory, isFalse);
    expect(remaining.savedAtUtc, isNotNull);
  });

  test('clearing history preserves saved QRs', () async {
    await controller.enable();
    await controller.recordScanned(payload: 'keep me');
    final saved = (await repository.watchRecent().first).single;
    await controller.save(saved.id);
    await controller.recordScanned(payload: 'discard me');

    await controller.clear();

    final remaining = (await repository.watchRecent().first).single;
    expect(remaining.rawPayload, 'keep me');
    expect(remaining.isInHistory, isFalse);
    expect(remaining.savedAtUtc, isNotNull);
  });

  test('saved QR remains accessible regardless of age', () async {
    await repository.save(
      QrHistoryItem(
        id: 'old-saved',
        activityKind: QrActivityKind.created,
        payloadKind: QrPayloadKind.text,
        rawPayload: 'old saved value',
        displayHost: null,
        savedAtUtc: DateTime.utc(2026, 8, 2),
        source: QrActivitySource.manual,
        createdAtUtc: DateTime.utc(2026, 8, 1),
      ),
    );
    await controller.enable();

    final remaining = (await repository.watchRecent().first).single;
    expect(remaining.isInHistory, isTrue);
    expect(remaining.savedAtUtc, isNotNull);
    expect(controller.items.single.id, 'old-saved');
    expect(controller.savedItems.single.id, 'old-saved');
  });

  test(
    'removing from Saved retains history or deletes a saved-only QR',
    () async {
      await controller.enable();
      await controller.recordScanned(payload: 'history and saved');
      var item = (await repository.watchRecent().first).single;
      await controller.save(item.id);
      await controller.removeFromSaved(item.id);

      item = (await repository.watchRecent().first).single;
      expect(item.isInHistory, isTrue);
      expect(item.savedAtUtc, isNull);

      await controller.save(item.id);
      await controller.delete(item.id);
      await controller.removeFromSaved(item.id);
      expect(await repository.watchRecent().first, isEmpty);
    },
  );
}

final class _MemoryHistorySettings implements HistorySettingsStore {
  bool enabled = false;

  @override
  Future<bool> historyEnabled() async => enabled;

  @override
  Future<void> setHistoryEnabled(bool value) async {
    enabled = value;
  }
}
