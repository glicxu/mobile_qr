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
              title: row.title,
              note: row.note,
              isInHistory: row.isInHistory,
              savedAtUtc: row.savedAtUtc,
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
            title: Value(item.title),
            note: Value(item.note),
            isInHistory: Value(item.isInHistory),
            savedAtUtc: Value(item.savedAtUtc),
            verificationCode: Value(item.verificationCode),
            registrableDomain: Value(item.registrableDomain),
            qrPngBytes: Value(item.qrPngBytes),
            source: item.source.index,
            createdAtUtc: item.createdAtUtc,
          ),
        );
  }

  @override
  Future<QrHistoryItem?> findMostRecentByPayload(String payload) async {
    final query = _database.select(_database.historyEntries)
      ..where((row) => row.rawPayload.equals(payload))
      ..orderBy([(row) => OrderingTerm.desc(row.createdAtUtc)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> setSavedAt(String id, DateTime? savedAtUtc) async {
    await (_database.update(_database.historyEntries)
          ..where((row) => row.id.equals(id)))
        .write(HistoryEntriesCompanion(savedAtUtc: Value(savedAtUtc)));
  }

  @override
  Future<void> setInHistory(String id, bool isInHistory) async {
    await (_database.update(_database.historyEntries)
          ..where((row) => row.id.equals(id)))
        .write(HistoryEntriesCompanion(isInHistory: Value(isInHistory)));
  }

  @override
  Future<void> updateMetadata(String id, {String? title, String? note}) async {
    await (_database.update(_database.historyEntries)
          ..where((row) => row.id.equals(id)))
        .write(HistoryEntriesCompanion(title: Value(title), note: Value(note)));
  }

  @override
  Future<void> removeFromHistory(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.historyEntries,
      )..where((row) => row.id.equals(id) & row.savedAtUtc.isNull())).go();
      await (_database.update(_database.historyEntries)
            ..where((row) => row.id.equals(id)))
          .write(const HistoryEntriesCompanion(isInHistory: Value(false)));
    });
  }

  @override
  Future<void> removeFromSaved(String id) async {
    await _database.transaction(() async {
      await (_database.delete(_database.historyEntries)
            ..where((row) => row.id.equals(id) & row.isInHistory.equals(false)))
          .go();
      await (_database.update(_database.historyEntries)
            ..where((row) => row.id.equals(id)))
          .write(const HistoryEntriesCompanion(savedAtUtc: Value(null)));
    });
  }

  @override
  Future<void> deleteExpired(DateTime cutoffUtc) async {
    await _database.transaction(() async {
      final expired = _database.historyEntries.createdAtUtc.isSmallerThanValue(
        cutoffUtc,
      );
      await (_database.delete(
        _database.historyEntries,
      )..where((row) => expired & row.savedAtUtc.isNull())).go();
      await (_database.update(_database.historyEntries)
            ..where((row) => expired & row.savedAtUtc.isNotNull()))
          .write(const HistoryEntriesCompanion(isInHistory: Value(false)));
    });
  }

  @override
  Future<void> clearHistory() async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.historyEntries,
      )..where((row) => row.savedAtUtc.isNull())).go();
      await _database
          .update(_database.historyEntries)
          .write(const HistoryEntriesCompanion(isInHistory: Value(false)));
    });
  }

  @override
  Future<void> close() => _database.close();

  static QrHistoryItem _toDomain(HistoryEntry row) => QrHistoryItem(
    id: row.id,
    activityKind: QrActivityKind.values[row.activityKind],
    payloadKind: QrPayloadKind.values[row.payloadKind],
    rawPayload: row.rawPayload,
    displayHost: row.displayHost,
    title: row.title,
    note: row.note,
    isInHistory: row.isInHistory,
    savedAtUtc: row.savedAtUtc,
    verificationCode: row.verificationCode,
    registrableDomain: row.registrableDomain,
    qrPngBytes: row.qrPngBytes,
    source: QrActivitySource.values[row.source],
    createdAtUtc: row.createdAtUtc,
  );
}
