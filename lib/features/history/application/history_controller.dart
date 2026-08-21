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
  List<QrHistoryItem> _items = const [];
  bool _enabled = false;
  HistoryRetention _retention = HistoryRetention.thirtyDays;

  List<QrHistoryItem> get items => _items;
  bool get enabled => _enabled;
  HistoryRetention get retention => _retention;

  Future<void> initialize() async {
    _enabled = await _settings.historyEnabled();
    _retention = await _settings.retention();
    if (_enabled) {
      await _deleteExpired();
      _watch();
    }
    notifyListeners();
  }

  Future<void> enable() async {
    if (_enabled) return;
    await _settings.setHistoryEnabled(true);
    _enabled = true;
    await _deleteExpired();
    _watch();
    notifyListeners();
  }

  Future<void> disable({required bool deleteExisting}) async {
    await _settings.setHistoryEnabled(false);
    _enabled = false;
    await _subscription?.cancel();
    _subscription = null;
    if (deleteExisting) await _repository.clear();
    _items = const [];
    notifyListeners();
  }

  Future<void> setRetention(HistoryRetention value) async {
    _retention = value;
    await _settings.setRetention(value);
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

  Future<void> delete(String id) => _repository.delete(id);

  Future<void> clear() => _repository.clear();

  void _watch() {
    unawaited(_subscription?.cancel());
    _subscription = _repository.watchRecent().listen((items) {
      _items = items;
      notifyListeners();
    });
  }

  Future<void> _deleteExpired() async {
    final days = _retention.days;
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
