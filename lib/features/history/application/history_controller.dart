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
  static const freeHistoryAccess = Duration(days: 7);

  StreamSubscription<List<QrHistoryItem>>? _subscription;
  List<QrHistoryItem> _allItems = const [];
  bool _enabled = false;
  bool _extendedHistoryUnlocked = false;

  List<QrHistoryItem> get items => _allItems
      .where((item) => item.isInHistory && _canAccess(item))
      .toList(growable: false);
  int get lockedItemCount =>
      _allItems.where((item) => item.isInHistory && !_canAccess(item)).length;
  List<QrHistoryItem> get savedItems {
    final saved = _allItems
        .where((item) => item.savedAtUtc != null)
        .toList(growable: false);
    saved.sort((a, b) => b.savedAtUtc!.compareTo(a.savedAtUtc!));
    return saved;
  }

  bool get enabled => _enabled;
  bool get extendedHistoryUnlocked => _extendedHistoryUnlocked;
  DateTime now() => _now();

  Future<void> initialize() async {
    _enabled = await _settings.historyEnabled();
    await _watch();
    notifyListeners();
  }

  Future<void> enable() async {
    if (_enabled) return;
    await _settings.setHistoryEnabled(true);
    _enabled = true;
    notifyListeners();
  }

  Future<void> disable({required bool deleteExisting}) async {
    await _settings.setHistoryEnabled(false);
    _enabled = false;
    if (deleteExisting) await _repository.clearHistory();
    notifyListeners();
  }

  Future<void> setExtendedHistoryUnlocked(bool unlocked) async {
    if (_extendedHistoryUnlocked == unlocked) return;
    _extendedHistoryUnlocked = unlocked;
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

  Future<void> _watch() async {
    await _subscription?.cancel();
    final firstItems = Completer<void>();
    _subscription = _repository.watchRecent().listen((items) {
      _allItems = items;
      if (!firstItems.isCompleted) firstItems.complete();
      notifyListeners();
    }, onError: firstItems.completeError);
    await firstItems.future;
  }

  bool _canAccess(QrHistoryItem item) {
    if (_extendedHistoryUnlocked || item.savedAtUtc != null) return true;
    final cutoff = _now().toUtc().subtract(freeHistoryAccess);
    return !item.createdAtUtc.isBefore(cutoff);
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
