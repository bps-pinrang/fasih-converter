import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:json_converter/app/data/core/values/strings.dart';
import 'package:json_converter/app/data/models/backup_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

@singleton
class SettingsRepository {
  static const _credKey = kPrefKeyCredentials;
  static const _sheetIdKey = kPrefKeySheetId;
  static const _lastDirKey = kPrefKeyLastExtractedDir;
  static const _lastTemplateKey = kPrefKeyLastTemplateId;
  static const _lastZipNameKey = kPrefKeyLastZipName;
  static const _lastZipSizeKey = kPrefKeyLastZipSize;
  static const _historyKey = kPrefKeySessionHistory;
  static const _maxHistory = 10;

  final SharedPreferences _prefs;

  const SettingsRepository(this._prefs);

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

  String? get lastExtractedDirPath => _prefs.getString(_lastDirKey);
  String? get lastTemplateId => _prefs.getString(_lastTemplateKey);
  String? get lastZipName => _prefs.getString(_lastZipNameKey);
  int get lastZipSize => _prefs.getInt(_lastZipSizeKey) ?? 0;

  Future<void> saveLastSession({
    required String extractedDirPath,
    required String templateId,
    required String zipName,
    required int zipSize,
  }) async {
    await _prefs.setString(_lastDirKey, extractedDirPath);
    await _prefs.setString(_lastTemplateKey, templateId);
    await _prefs.setString(_lastZipNameKey, zipName);
    await _prefs.setInt(_lastZipSizeKey, zipSize);
  }

  Future<void> clearLastSession() async {
    await _prefs.remove(_lastDirKey);
    await _prefs.remove(_lastTemplateKey);
    await _prefs.remove(_lastZipNameKey);
    await _prefs.remove(_lastZipSizeKey);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_credKey);
    await _prefs.remove(_sheetIdKey);
  }

  List<BackupHistoryEntry> loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return [];
    return BackupHistoryEntry.listFromJsonString(raw);
  }

  Future<void> addToHistory(BackupHistoryEntry entry) async {
    final history = loadHistory()
      ..removeWhere((e) => e.dirPath == entry.dirPath)
      ..insert(0, entry);
    final capped = history.take(_maxHistory).toList();
    await _prefs.setString(
      _historyKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeFromHistory(String dirPath) async {
    final history = loadHistory()..removeWhere((e) => e.dirPath == dirPath);
    await _prefs.setString(
      _historyKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
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
