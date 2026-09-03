import 'package:shared_preferences/shared_preferences.dart';

import '../domain/qr_history.dart';

final class SharedPreferencesHistorySettings implements HistorySettingsStore {
  SharedPreferencesHistorySettings({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _enabledKey = 'history.enabled';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> historyEnabled() async {
    return await _preferences.getBool(_enabledKey) ?? false;
  }

  @override
  Future<void> setHistoryEnabled(bool enabled) {
    return _preferences.setBool(_enabledKey, enabled);
  }
}
