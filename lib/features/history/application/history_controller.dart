import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../create/domain/url_payload_policy.dart';
import '../data/drift_qr_history_repository.dart';
import '../data/history_database.dart';
import '../data/shared_preferences_history_settings.dart';
import '../domain/qr_history.dart';

final class HistoryController extends ChangeNotifier {
  HistoryController(
    this._repository,
    this._settings, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static Future<HistoryController> open() async {
    final controller = HistoryController(
      DriftQrHistoryRepository(HistoryDatabase()),
      SharedPreferencesHistorySettings(),
    );
    await controller.initialize();
    return controller;
  }

  final QrHistoryRepository _repository;
  final HistorySettingsStore _settings;
  final DateTime Function() _now;
  final Random _random = Random.secure();
  static const _urlPolicy = UrlPayloadPolicy();

  StreamSubscription<List<QrHistoryItem>>? _subscription;
  List<QrHistoryItem> _allItems = const [];
  bool _enabled = false;
  HistoryRetention _retention = HistoryRetention.thirtyDays;
  bool _extendedHistoryUnlocked = false;

  List<QrHistoryItem> get items =>
      _allItems.where((item) => item.isInHistory).toList(growable: false);
  List<QrHistoryItem> get savedItems {
    final saved = _allItems
        .where((item) => item.savedAtUtc != null)
        .toList(growable: false);
    saved.sort((a, b) => b.savedAtUtc!.compareTo(a.savedAtUtc!));
    return saved;
  }

  bool get enabled => _enabled;
  HistoryRetention get retention =>
      _extendedHistoryUnlocked ? _retention : HistoryRetention.oneDay;
  bool get extendedHistoryUnlocked => _extendedHistoryUnlocked;
  DateTime now() => _now();

  Future<void> initialize() async {
    _enabled = await _settings.historyEnabled();
    _retention = await _settings.retention();
    await _deleteExpired();
    _watch();
    notifyListeners();
  }

  Future<void> enable() async {
    if (_enabled) return;
    await _settings.setHistoryEnabled(true);
    _enabled = true;
    await _deleteExpired();
    notifyListeners();
  }

  Future<void> disable({required bool deleteExisting}) async {
    await _settings.setHistoryEnabled(false);
    _enabled = false;
    if (deleteExisting) await _repository.clearHistory();
    notifyListeners();
  }

  Future<void> setRetention(HistoryRetention value) async {
    if (!_extendedHistoryUnlocked && value != HistoryRetention.oneDay) return;
    _retention = value;
    await _settings.setRetention(value);
    await _deleteExpired();
    notifyListeners();
  }

  Future<void> setExtendedHistoryUnlocked(bool unlocked) async {
    if (_extendedHistoryUnlocked == unlocked) return;
    _extendedHistoryUnlocked = unlocked;
    await _deleteExpired();
    notifyListeners();
  }

  Future<void> recordCreated({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    required Uint8List qrPngBytes,
  }) {
    return _record(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
      activityKind: QrActivityKind.created,
      source: QrActivitySource.manual,
    );
  }

  Future<void> recordScanned({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
  }) {
    return _record(
      payload: payload,
      verificationCode: verificationCode,
      registrableDomain: registrableDomain,
      qrPngBytes: qrPngBytes,
      activityKind: QrActivityKind.scanned,
      source: QrActivitySource.camera,
    );
  }

  Future<void> _record({
    required String payload,
    required String? verificationCode,
    required String? registrableDomain,
    required Uint8List? qrPngBytes,
    required QrActivityKind activityKind,
    required QrActivitySource source,
  }) async {
    if (!_enabled) return;
    final existing = await _repository.findMostRecentByPayload(payload);
    if (existing != null &&
        !existing.isInHistory &&
        existing.savedAtUtc != null) {
      await _repository.setInHistory(existing.id, true);
      return;
    }
    ValidatedUrlPayload? urlPayload;
    try {
      urlPayload = _urlPolicy.validate(payload);
    } on UrlPayloadValidationException {
      // Scanned QR codes may contain arbitrary text.
    }
    final nowUtc = _now().toUtc();
    await _repository.save(
      QrHistoryItem(
        id: _newId(nowUtc),
        activityKind: activityKind,
        payloadKind: urlPayload != null
            ? QrPayloadKind.url
            : QrPayloadKind.text,
        rawPayload: payload,
        displayHost: urlPayload?.uri.host,
        verificationCode: verificationCode,
        registrableDomain: registrableDomain,
        qrPngBytes: qrPngBytes,
        source: source,
        createdAtUtc: nowUtc,
      ),
    );
    await _deleteExpired();
  }

  Future<void> delete(String id) => _repository.removeFromHistory(id);

  Future<void> save(String id) => _repository.setSavedAt(id, _now().toUtc());

  Future<void> removeFromSaved(String id) => _repository.removeFromSaved(id);

  Future<void> savePayload({
    required String payload,
    String? verificationCode,
    String? registrableDomain,
    Uint8List? qrPngBytes,
    required QrActivityKind activityKind,
    required QrActivitySource source,
  }) async {
    final nowUtc = _now().toUtc();
    final existing = await _repository.findMostRecentByPayload(payload);
    if (existing != null) {
      await _repository.setSavedAt(existing.id, nowUtc);
      return;
    }
    ValidatedUrlPayload? urlPayload;
    try {
      urlPayload = _urlPolicy.validate(payload);
    } on UrlPayloadValidationException {
      // Saved QR codes may contain arbitrary text.
    }
    await _repository.save(
      QrHistoryItem(
        id: _newId(nowUtc),
        activityKind: activityKind,
        payloadKind: urlPayload == null
            ? QrPayloadKind.text
            : QrPayloadKind.url,
        rawPayload: payload,
        displayHost: urlPayload?.uri.host,
        verificationCode: verificationCode,
        registrableDomain: registrableDomain,
        qrPngBytes: qrPngBytes,
        source: source,
        createdAtUtc: nowUtc,
        isInHistory: false,
        savedAtUtc: nowUtc,
      ),
    );
  }

  Future<void> updateMetadata(String id, {String? title, String? note}) {
    return _repository.updateMetadata(
      id,
      title: _normalizeMetadata(title),
      note: _normalizeMetadata(note),
    );
  }

  static String? _normalizeMetadata(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> clear() => _repository.clearHistory();

  void _watch() {
    unawaited(_subscription?.cancel());
    _subscription = _repository.watchRecent().listen((items) {
      _allItems = items;
      notifyListeners();
    });
  }

  Future<void> _deleteExpired() async {
    final days = retention.days;
    if (days == null) return;
    await _repository.deleteExpired(
      _now().toUtc().subtract(Duration(days: days)),
    );
  }

  String _newId(DateTime nowUtc) {
    final random = List.generate(
      12,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${nowUtc.microsecondsSinceEpoch}-$random';
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_repository.close());
    super.dispose();
  }
}
