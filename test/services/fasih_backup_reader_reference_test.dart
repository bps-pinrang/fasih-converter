import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';

void main() {
  group('parseReferenceJson', () {
    test('returns empty map for empty details array', () {
      final raw = jsonEncode({'details': []});
      expect(FasihBackupReader.parseReferenceJson(raw), isEmpty);
    });

    test('extracts dataKey/answer pairs from details', () {
      final raw = jsonEncode({
        'details': [
          {'dataKey': 'prov', 'answer': '[51] BALI', 'type': 25},
          {'dataKey': 'kab', 'answer': '[02] TABANAN', 'type': 25},
        ],
      });
      final result = FasihBackupReader.parseReferenceJson(raw);
      expect(result['prov'], '[51] BALI');
      expect(result['kab'], '[02] TABANAN');
    });

    test('skips entries with null answer', () {
      final raw = jsonEncode({
        'details': [
          {'dataKey': 'nup', 'answer': null, 'type': 25},
          {'dataKey': 'prov', 'answer': '[51] BALI', 'type': 25},
        ],
      });
      final result = FasihBackupReader.parseReferenceJson(raw);
      expect(result.containsKey('nup'), isFalse);
      expect(result['prov'], '[51] BALI');
    });

    test('skips entries with empty string answer', () {
      final raw = jsonEncode({
        'details': [
          {'dataKey': 'nup', 'answer': '', 'type': 25},
        ],
      });
      expect(FasihBackupReader.parseReferenceJson(raw), isEmpty);
    });

    test('skips entries without dataKey', () {
      final raw = jsonEncode({
        'details': [
          {'answer': '[51] BALI', 'type': 1},
        ],
      });
      expect(FasihBackupReader.parseReferenceJson(raw), isEmpty);
    });

    test('returns empty map for malformed JSON', () {
      expect(FasihBackupReader.parseReferenceJson('not json'), isEmpty);
    });

    test('returns empty map when details key is missing', () {
      expect(
        FasihBackupReader.parseReferenceJson(jsonEncode({'sidebar': {}})),
        isEmpty,
      );
    });
  });
}
