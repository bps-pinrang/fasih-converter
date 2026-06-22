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

  group('cross-template guard — 20% threshold', () {
    // Simulate a legacy record (no templateId / templateDataKey).
    Map<String, dynamic> legacyDataMap(List<Map<String, dynamic>> answers) => {
          'answers': answers,
        };

    List<Map<String, dynamic>> answersFor(List<String> keys) =>
        keys.map((k) => {'dataKey': k, 'answer': 'x'}).toList();

    test('accepts legacy record when ≥20% of its keys match template', () {
      // 10 answer keys, 3 match template (30%) → accept
      final record = FasihBackupReader.buildRecordFromMaps(
        legacyDataMap(answersFor([
          'prov', 'kab', 'r501', // match
          'ada_usaha', 'kode_bang', 'kbli_1', 'kbli_2', 'kbli_3', 'kbli_4',
          'kbli_5',
        ])),
        fieldKeys: {'prov', 'kab', 'r501', 'kec', 'desa'},
      );
      expect(record, isNotNull);
    });

    test('rejects legacy SE2026-like record with <20% key overlap', () {
      // 10 answer keys, only 1 matches template (10%) → reject
      final record = FasihBackupReader.buildRecordFromMaps(
        legacyDataMap(answersFor([
          'prov', // match
          'ada_usaha', 'kode_bang', 'kbli_1', 'kbli_2', 'kbli_3', 'kbli_4',
          'kbli_5', 'kbli_6', 'kbli_7',
        ])),
        fieldKeys: {'prov', 'kab', 'r501', 'kec', 'desa'},
      );
      expect(record, isNull);
    });

    test('rejects VHTS-like record with many keys but tiny overlap', () {
      // 50 answer keys, 2 match template (4%) → reject
      final allKeys = List.generate(48, (i) => 'vhts_field_$i')
        ..addAll(['prov', 'kab']);
      final record = FasihBackupReader.buildRecordFromMaps(
        legacyDataMap(answersFor(allKeys)),
        fieldKeys: {'prov', 'kab', 'r501', 'r502', 'r503', 'sumberdata'},
      );
      expect(record, isNull);
    });

    test('accepts SAK prelist-like legacy record with high overlap', () {
      // 30 answer keys, 15 match template (50%) → accept
      final sakKeys = [
        'prov',
        'kab',
        'kec',
        'desa',
        'sls',
        'r501',
        'r502',
        'r503',
        'r504',
        'r505',
        'r506',
        'r507',
        'r508',
        'r509',
        'id_prelist',
      ];
      final otherKeys = List.generate(15, (i) => 'computed_$i');
      final record = FasihBackupReader.buildRecordFromMaps(
        legacyDataMap(answersFor([...sakKeys, ...otherKeys])),
        fieldKeys: {
          'prov',
          'kab',
          'kec',
          'desa',
          'sls',
          'r501',
          'r502',
          'r503',
          'r504',
          'r505',
          'r506',
          'r507',
          'r508',
          'r509',
          'id_prelist',
          'sumberdata',
          'catatan',
        },
      );
      expect(record, isNotNull);
    });

    test('records with declared templateId bypass threshold entirely', () {
      // Only 1 of 10 keys matches, but templateId is declared and matches.
      final record = FasihBackupReader.buildRecordFromMaps(
        {
          'templateId': 'tmpl-abc',
          'templateDataKey': 'my_survey',
          'answers': answersFor([
            'prov',
            'ada_usaha',
            'kode_bang',
            'kbli_1',
            'kbli_2',
            'kbli_3',
            'kbli_4',
            'kbli_5',
            'kbli_6',
            'kbli_7',
          ]),
        },
        templateId: 'tmpl-abc',
        templateDataKey: 'my_survey',
        fieldKeys: {'prov', 'kab', 'r501'},
      );
      // Must pass because templateId matches — threshold is a guard for
      // LEGACY (undeclared) records only.
      expect(record, isNotNull);
    });
  });
}
