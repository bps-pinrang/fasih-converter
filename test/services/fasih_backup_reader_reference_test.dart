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

  group('reference merge in record building', () {
    test('reference fills key absent from data answers', () {
      final dataMap = {
        'templateDataKey': 'VHTS_2026',
        'templateId': 'uuid-1',
        'answers': [
          {'dataKey': 'prov', 'answer': '[51] BALI'},
        ],
      };
      final refMap = {'nup': '001', 'prov': '[99] OVERRIDE'};
      final record = FasihBackupReader.buildRecordFromMaps(
        dataMap,
        referenceMap: refMap,
        templateId: 'uuid-1',
        templateDataKey: 'VHTS_2026',
        fieldKeys: {'prov', 'nup'},
      );
      expect(record, isNotNull);
      expect(record!.values['prov'], '[51] BALI'); // data wins
      expect(record.values['nup'], '001'); // reference fills gap
    });

    test('data.json answer wins over reference when both present', () {
      final dataMap = {
        'templateDataKey': 'VHTS_2026',
        'templateId': 'uuid-1',
        'answers': [
          {'dataKey': 'prov', 'answer': '[51] BALI'},
        ],
      };
      final refMap = {'prov': '[99] SHOULD NOT WIN'};
      final record = FasihBackupReader.buildRecordFromMaps(
        dataMap,
        referenceMap: refMap,
        templateId: 'uuid-1',
        templateDataKey: 'VHTS_2026',
        fieldKeys: {'prov'},
      );
      expect(record!.values['prov'], '[51] BALI');
    });

    test('reference-only keys satisfy cross-template guard', () {
      final dataMap = {
        'templateDataKey': 'VHTS_2026',
        'templateId': 'uuid-1',
        'answers': <Map<String, dynamic>>[],
      };
      final refMap = {'nup': '001'};
      final record = FasihBackupReader.buildRecordFromMaps(
        dataMap,
        referenceMap: refMap,
        templateId: 'uuid-1',
        templateDataKey: 'VHTS_2026',
        fieldKeys: {'nup', 'prov'},
      );
      expect(record, isNotNull);
      expect(record!.values['nup'], '001');
    });

    test('null referenceMap is a no-op', () {
      final dataMap = {
        'templateDataKey': 'VHTS_2026',
        'templateId': 'uuid-1',
        'answers': [
          {'dataKey': 'prov', 'answer': '[51] BALI'},
        ],
      };
      final record = FasihBackupReader.buildRecordFromMaps(
        dataMap,
        referenceMap: null,
        templateId: 'uuid-1',
        templateDataKey: 'VHTS_2026',
        fieldKeys: {'prov'},
      );
      expect(record!.values['prov'], '[51] BALI');
    });
  });
}
