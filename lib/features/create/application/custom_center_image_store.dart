import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CustomImageStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

final class SharedPreferencesCustomImageStorage implements CustomImageStorage {
  SharedPreferencesCustomImageStorage({this.preferences});

  final SharedPreferencesAsync? preferences;
  SharedPreferencesAsync? _resolved;

  SharedPreferencesAsync? get _prefs {
    if (preferences != null) return preferences;
    if (_resolved != null) return _resolved;
    try {
      return _resolved = SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getString(String key) =>
      _prefs?.getString(key) ?? Future.value(null);

  @override
  Future<void> setString(String key, String value) =>
      _prefs?.setString(key, value) ?? Future.value();

  @override
  Future<void> remove(String key) => _prefs?.remove(key) ?? Future.value();
}

final class InMemoryCustomImageStorage implements CustomImageStorage {
  InMemoryCustomImageStorage([Map<String, String>? initial])
    : _storage = initial ?? <String, String>{};

  final Map<String, String> _storage;

  @override
  Future<String?> getString(String key) async => _storage[key];

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}

class CustomCenterImageStore extends ChangeNotifier {
  CustomCenterImageStore({CustomImageStorage? storage})
    : _storage = storage ?? SharedPreferencesCustomImageStorage();

  static const _key = 'qr.custom_center_image';
  final CustomImageStorage _storage;

  Uint8List? _customImageBytes;
  bool _initialized = false;

  Uint8List? get customImageBytes => _customImageBytes;
  bool get hasCustomImage => _customImageBytes != null;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final base64String = await _storage.getString(_key);
      if (base64String != null && base64String.isNotEmpty) {
        _customImageBytes = base64Decode(base64String);
      }
    } catch (_) {
      // Best-effort recovery from storage.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setImage(Uint8List bytes) async {
    _customImageBytes = bytes;
    _initialized = true;
    notifyListeners();
    try {
      await _storage.setString(_key, base64Encode(bytes));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> clearImage() async {
    _customImageBytes = null;
    notifyListeners();
    try {} catch (_) {
      // Best-effort persistence.
    }
  }
}
