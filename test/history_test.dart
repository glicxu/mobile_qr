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

  test('retention removes expired entries', () async {
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
    await controller.setRetention(HistoryRetention.sevenDays);

    expect(await repository.watchRecent().first, isEmpty);
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
}

final class _MemoryHistorySettings implements HistorySettingsStore {
  bool enabled = false;
  HistoryRetention retentionValue = HistoryRetention.thirtyDays;

  @override
  Future<bool> historyEnabled() async => enabled;

  @override
  Future<HistoryRetention> retention() async => retentionValue;

  @override
  Future<void> setHistoryEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<void> setRetention(HistoryRetention value) async {
    retentionValue = value;
  }
}
