import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository.extractSheetId', () {
    test('extracts ID from full Google Sheets URL', () {
      const url =
          'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit';
      expect(
        SettingsRepository.extractSheetId(url),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms',
      );
    });

    test('returns bare ID unchanged', () {
      const id = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms';
      expect(SettingsRepository.extractSheetId(id), id);
    });

    test('returns null for empty string', () {
      expect(SettingsRepository.extractSheetId(''), null);
    });
  });

  group('SettingsRepository.validateCredentialJson', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    test('returns true for valid service account JSON', () {
      const json =
          '{"type":"service_account","client_email":"test@project.iam.gserviceaccount.com","private_key":"key"}';
      expect(repo.validateCredentialJson(json), isTrue);
    });

    test('returns false when type is not service_account', () {
      const json = '{"type":"oauth2","client_email":"x","private_key":"y"}';
      expect(repo.validateCredentialJson(json), isFalse);
    });

    test('returns false for malformed JSON', () {
      expect(repo.validateCredentialJson('not json'), isFalse);
    });
  });
}
