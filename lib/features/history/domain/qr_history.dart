import 'dart:typed_data';

enum QrActivityKind { created, scanned }

enum QrPayloadKind { url, text }

enum QrActivitySource { manual, camera }

enum HistoryRetention {
  sevenDays('7 days', 7),
  thirtyDays('30 days', 30),
  oneYear('1 year', 365),
  forever('Forever', null);

  const HistoryRetention(this.label, this.days);

  final String label;
  final int? days;
}

final class QrHistoryItem {
  const QrHistoryItem({
    required this.id,
    required this.activityKind,
    required this.payloadKind,
    required this.rawPayload,
    required this.displayHost,
    this.title,
    this.note,
    this.isInHistory = true,
    this.savedAtUtc,
    this.verificationCode,
    this.registrableDomain,
    this.qrPngBytes,
    required this.source,
    required this.createdAtUtc,
  });

  final String id;
  final QrActivityKind activityKind;
  final QrPayloadKind payloadKind;
  final String rawPayload;
  final String? displayHost;
  final String? title;
  final String? note;
  final bool isInHistory;
  final DateTime? savedAtUtc;
  final String? verificationCode;
  final String? registrableDomain;
  final Uint8List? qrPngBytes;
  final QrActivitySource source;
  final DateTime createdAtUtc;
}

abstract interface class QrHistoryRepository {
  Stream<List<QrHistoryItem>> watchRecent();
  Future<void> save(QrHistoryItem item);
  Future<void> updateMetadata(String id, {String? title, String? note});
  Future<QrHistoryItem?> findMostRecentByPayload(String payload);
  Future<void> setSavedAt(String id, DateTime? savedAtUtc);
  Future<void> setInHistory(String id, bool isInHistory);
  Future<void> removeFromHistory(String id);
  Future<void> removeFromSaved(String id);
  Future<void> deleteExpired(DateTime cutoffUtc);
  Future<void> clearHistory();
  Future<void> close();
}

abstract interface class HistorySettingsStore {
  Future<bool> historyEnabled();
  Future<void> setHistoryEnabled(bool enabled);
  Future<HistoryRetention> retention();
  Future<void> setRetention(HistoryRetention retention);
}
