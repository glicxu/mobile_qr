import 'package:drift/drift.dart';

import '../domain/qr_history.dart';
import 'history_database.dart';

final class DriftQrHistoryRepository implements QrHistoryRepository {
  const DriftQrHistoryRepository(this._database);

  final HistoryDatabase _database;

  @override
  Stream<List<QrHistoryItem>> watchRecent() {
    final query = _database.select(_database.historyEntries)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAtUtc)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => QrHistoryItem(
              id: row.id,
              activityKind: QrActivityKind.values[row.activityKind],
              payloadKind: QrPayloadKind.values[row.payloadKind],
              rawPayload: row.rawPayload,
              displayHost: row.displayHost,
              verificationCode: row.verificationCode,
              registrableDomain: row.registrableDomain,
              qrPngBytes: row.qrPngBytes,
              source: QrActivitySource.values[row.source],
              createdAtUtc: row.createdAtUtc,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> save(QrHistoryItem item) {
    return _database
        .into(_database.historyEntries)
        .insert(
          HistoryEntriesCompanion.insert(
            id: item.id,
            activityKind: item.activityKind.index,
            payloadKind: item.payloadKind.index,
            rawPayload: item.rawPayload,
            displayHost: Value(item.displayHost),
            verificationCode: Value(item.verificationCode),
            registrableDomain: Value(item.registrableDomain),
            qrPngBytes: Value(item.qrPngBytes),
            source: item.source.index,
            createdAtUtc: item.createdAtUtc,
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.historyEntries,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> deleteExpired(DateTime cutoffUtc) async {
    await (_database.delete(
      _database.historyEntries,
    )..where((row) => row.createdAtUtc.isSmallerThanValue(cutoffUtc))).go();
  }

  @override
  Future<void> clear() => _database.delete(_database.historyEntries).go();

  @override
  Future<void> close() => _database.close();
}
