import 'dart:convert';

import '../../scan/domain/qr_payload_classifier.dart';
import '../../scan/domain/scanned_code.dart';

final class BatchSession {
  const BatchSession({
    required this.id,
    required this.name,
    required this.countDuplicates,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.itemCount = 0,
  });
  final String id;
  final String name;
  final bool countDuplicates;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int itemCount;
}

final class BatchItem {
  const BatchItem({
    required this.id,
    required this.sessionId,
    required this.value,
    required this.format,
    required this.sourceKey,
    required this.quantity,
    required this.firstSeenUtc,
    required this.lastSeenUtc,
    this.storedFormatKey,
  });
  final String id;
  final String sessionId;
  final String value;
  final ScannedCodeFormat format;
  final String? storedFormatKey;
  String get formatKey => storedFormatKey ?? format.storageKey;
  final String sourceKey;
  final int quantity;
  final DateTime firstSeenUtc;
  final DateTime lastSeenUtc;
  String get sourceLabel => switch (sourceKey) {
    'camera' => 'Camera',
    'gallery' => 'Photo library',
    'sharedImage' => 'Shared image',
    _ => 'Unknown source',
  };
}

abstract interface class BatchRepository {
  Future<List<BatchSession>> listSessions();
  Future<BatchSession> createSession(
    String name, {
    required bool countDuplicates,
  });
  Future<List<BatchItem>> items(String sessionId);

  /// Returns false for an ignored duplicate in unique mode.
  Future<bool> addCode(String sessionId, ScannedCode code);
  Future<void> setQuantity(String itemId, int quantity);
  Future<void> removeItem(String itemId);
  Future<void> deleteSession(String sessionId);
  Future<void> close();
}

abstract final class BatchPolicy {
  static const maxSessions = 50;
  static const maxItems = 1000;
  static const maxPayloadBytes = 4096;
  static const maxSessionBytes = 1024 * 1024;
  static const maxQuantity = 999999;

  static void validateCode(ScannedCode code) {
    if (code.value.isEmpty ||
        utf8.encode(code.value).length > maxPayloadBytes) {
      throw ArgumentError(
        'Use a nonempty value no larger than 4096 UTF-8 bytes.',
      );
    }
    final raw = code.value.trimLeft().toUpperCase();
    final payload = const QrPayloadClassifier().classify(code.value);
    final type = payload.type;
    if (raw.startsWith('FIDO:') ||
        raw.startsWith('WIFI:') ||
        ['MAILTO:', 'TEL:', 'SMS:', 'SMSTO:'].any(raw.startsWith) ||
        RegExp(r'^HTTPS?://[^/?#]*@').hasMatch(raw) ||
        (payload.linkInspection?.uri?.userInfo.isNotEmpty ?? false) ||
        raw.contains('BEGIN:VCALENDAR') ||
        raw.contains('BEGIN:VCARD') ||
        raw.contains('BEGIN:VEVENT') ||
        {
          QrContentType.passkey,
          QrContentType.authenticator,
          QrContentType.wifi,
          QrContentType.contact,
          QrContentType.calendarEvent,
          QrContentType.email,
          QrContentType.phone,
          QrContentType.sms,
        }.contains(type)) {
      throw ArgumentError(
        'Credentials, contacts, messages, and calendar data are not recorded in batch sessions.',
      );
    }
    if (code.format == ScannedCodeFormat.unknown) {
      throw ArgumentError(
        'This code format is not supported in batch sessions.',
      );
    }
  }

  static String sessionName(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(clean)) {
      throw ArgumentError(
        'Use a session name of 1–80 characters without line breaks.',
      );
    }
    return clean;
  }
}
