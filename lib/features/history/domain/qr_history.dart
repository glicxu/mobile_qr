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
  final String? verificationCode;
  final String? registrableDomain;
  final Uint8List? qrPngBytes;
  final QrActivitySource source;
  final DateTime createdAtUtc;
}

abstract interface class QrHistoryRepository {
  Stream<List<QrHistoryItem>> watchRecent();
  Future<void> save(QrHistoryItem item);
  Future<void> delete(String id);
  Future<void> deleteExpired(DateTime cutoffUtc);
  Future<void> clear();
  Future<void> close();
}

abstract interface class HistorySettingsStore {
  Future<bool> historyEnabled();
  Future<void> setHistoryEnabled(bool enabled);
  Future<HistoryRetention> retention();
  Future<void> setRetention(HistoryRetention retention);
}
