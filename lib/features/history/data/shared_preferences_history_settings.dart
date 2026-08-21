import 'package:shared_preferences/shared_preferences.dart';

import '../domain/qr_history.dart';

final class SharedPreferencesHistorySettings implements HistorySettingsStore {
  SharedPreferencesHistorySettings({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _enabledKey = 'history.enabled';
  static const _retentionKey = 'history.retention';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> historyEnabled() async {
    return await _preferences.getBool(_enabledKey) ?? false;
  }

  @override
  Future<void> setHistoryEnabled(bool enabled) {
    return _preferences.setBool(_enabledKey, enabled);
  }

  @override
  Future<HistoryRetention> retention() async {
    final stored = await _preferences.getString(_retentionKey);
    return HistoryRetention.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => HistoryRetention.thirtyDays,
    );
  }

  @override
  Future<void> setRetention(HistoryRetention retention) {
    return _preferences.setString(_retentionKey, retention.name);
  }
}
