import 'dart:convert';

import 'package:json_converter/app/data/core/values/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _credKey = kPrefKeyCredentials;
  static const _sheetIdKey = kPrefKeySheetId;

  static SettingsRepository? _instance;
  static SettingsRepository get instance => _instance!;

  final SharedPreferences _prefs;

  SettingsRepository._(this._prefs);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SettingsRepository._(prefs);
  }

  String? get credentialsJson => _prefs.getString(_credKey);
  String? get sheetId => _prefs.getString(_sheetIdKey);

  bool get isConfigured =>
      credentialsJson != null &&
      credentialsJson!.isNotEmpty &&
      sheetId != null &&
      sheetId!.isNotEmpty;

  Future<void> saveCredentials(String json) => _prefs.setString(_credKey, json);

  Future<void> saveSheetId(String id) => _prefs.setString(_sheetIdKey, id);

  Future<void> clearCredentials() => _prefs.remove(_credKey);

  Future<void> clearSheetId() => _prefs.remove(_sheetIdKey);

  Future<void> clearAll() async {
    await _prefs.remove(_credKey);
    await _prefs.remove(_sheetIdKey);
  }

  bool validateCredentialJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map['type'] == 'service_account' &&
          map.containsKey('client_email') &&
          map.containsKey('private_key');
    } catch (_) {
      return false;
    }
  }

  static String? extractSheetId(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.pathSegments.contains('d')) {
      final idx = uri.pathSegments.indexOf('d');
      if (idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    if (!input.contains('/') && input.isNotEmpty) return input;
    return null;
  }
}
