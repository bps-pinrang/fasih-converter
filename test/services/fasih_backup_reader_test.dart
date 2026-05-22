import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';

void main() {
  late Directory tempDir;
  late FasihBackupReader reader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fasih_test_');
    reader = FasihBackupReader();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('discoverTemplates', () {
    test('returns empty list when Template dir does not exist', () async {
      final result = await reader.discoverTemplates(tempDir);
      expect(result, isEmpty);
    });

    test('discovers template from UUID subdirectory', () async {
      const uuid = 'abc-123';
      const templateJson = '''
      {
        "title": "Survey Rumah Tangga",
        "dataKey": "ruta",
        "components": [[
          {"type": 25, "dataKey": "r101", "label": "Nama KRT"}
        ]]
      }
      ''';
      final templateDir = Directory('${tempDir.path}/Template/$uuid')
        ..createSync(recursive: true);
      File('${templateDir.path}/${uuid}_template.json')
          .writeAsStringSync(templateJson);

      final result = await reader.discoverTemplates(tempDir);

      expect(result.length, 1);
      expect(result.first.id, uuid);
      expect(result.first.title, 'Survey Rumah Tangga');
      expect(result.first.fields.length, 1);
      expect(result.first.fields.first.dataKey, 'r101');
    });

    test('skips UUID dirs without matching template file', () async {
      Directory('${tempDir.path}/Template/no-template-here')
          .createSync(recursive: true);

      final result = await reader.discoverTemplates(tempDir);
      expect(result, isEmpty);
    });

    test('loads validation rules when validation file exists', () async {
      const uuid = 'val-uuid';
      const templateJson = '''
      {
        "title": "Survey",
        "dataKey": "sv",
        "components": [[{"type": 25, "dataKey": "r101", "label": "Q1"}]]
      }
      ''';
      const validationJson = '''
      {
        "testFunctions": [
          {
            "dataKey": "r101",
            "componentValidation": ["r101"],
            "validations": [
              {"test": "r101 != null", "message": "Required", "type": 2}
            ]
          }
        ]
      }
      ''';
      final templateDir = Directory('${tempDir.path}/Template/$uuid')
        ..createSync(recursive: true);
      File('${templateDir.path}/${uuid}_template.json')
          .writeAsStringSync(templateJson);
      File('${templateDir.path}/${uuid}_validation.json')
          .writeAsStringSync(validationJson);

      final result = await reader.discoverTemplates(tempDir);

      expect(result.length, 1);
      expect(result.first.validationRules.length, 1);
      expect(result.first.validationRules.first.dataKey, 'r101');
      expect(result.first.validationRules.first.validations.length, 1);
      expect(result.first.validationRules.first.validations.first.type, 2);
    });
  });

  group('loadRecords', () {
    test('returns empty list when no respondent dirs exist', () async {
      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
      expect(result.meta, isEmpty);
    });

    test('skips directories in _skipDirs', () async {
      for (final skip in [
        'Template',
        'env',
        'lookup',
        'formengine',
        'backup',
      ]) {
        final dir = Directory('${tempDir.path}/$skip/answers/q1/section1/item1')
          ..createSync(recursive: true);
        _writeDataJson(dir, [
          {'dataKey': 'r101', 'answer': 'should not appear'},
        ]);
      }
      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
    });

    test('parses respondent data.json answers at 3 levels deep', () async {
      final respDir = Directory(
        '${tempDir.path}/respondent-uuid-1/answers/q1/section1/item1',
      )..createSync(recursive: true);
      _writeDataJson(respDir, [
        {'dataKey': 'r101', 'answer': 'Ahmad'},
        {'dataKey': 'r102', 'answer': '35'},
      ]);

      final result = await reader.loadRecords(tempDir, _testTemplate());

      expect(result.records.length, 1);
      expect(result.records.first['r101'], 'Ahmad');
      expect(result.records.first['r102'], '35');
      expect(result.meta.length, 1);
      expect(result.meta.first.respUuid, 'respondent-uuid-1');
      expect(result.meta.first.answersRelPath, 'q1/section1/item1');
    });

    test('merges multiple data.json files under one respondent', () async {
      final dir1 = Directory(
        '${tempDir.path}/respondent-uuid-2/answers/q1/section1/item1',
      )..createSync(recursive: true);
      _writeDataJson(dir1, [
        {'dataKey': 'r101', 'answer': 'Budi'},
      ]);

      final dir2 = Directory(
        '${tempDir.path}/respondent-uuid-2/answers/q2/section1/item1',
      )..createSync(recursive: true);
      _writeDataJson(dir2, [
        {'dataKey': 'r102', 'answer': '40'},
      ]);

      final result = await reader.loadRecords(tempDir, _testTemplate());

      expect(result.records.length, 1);
      expect(result.records.first['r101'], 'Budi');
      expect(result.records.first['r102'], '40');
      expect(result.meta.length, 2);
    });

    test('handles array-type answers', () async {
      final respDir = Directory(
        '${tempDir.path}/resp-2/answers/q1/section1/item1',
      )..createSync(recursive: true);
      _writeDataJson(respDir, [
        {
          'dataKey': 'r201',
          'answer': [
            {'value': '1', 'label': 'Laki-laki'},
          ],
        },
      ]);

      final result = await reader.loadRecords(tempDir, _testTemplate());

      expect(result.records.length, 1);
      expect(result.records.first['r201'], '[1] Laki-laki');
    });

    test('silently skips malformed data.json files', () async {
      final respDir = Directory(
        '${tempDir.path}/resp-bad/answers/q1/section1/item1',
      )..createSync(recursive: true);
      File('${respDir.path}/data.json').writeAsStringSync('not valid json');

      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
    });

    test('silently skips data.json without answers key', () async {
      final respDir = Directory(
        '${tempDir.path}/resp-empty/answers/q1/section1/item1',
      )..createSync(recursive: true);
      File('${respDir.path}/data.json')
          .writeAsStringSync(jsonEncode({'other': 'data'}));

      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
    });

    test('session format: two respondents under one session', () async {
      const templateId = 'test-uuid';
      final resp1 = Directory(
        '${tempDir.path}/session-1/answers/resp-A/assign1/section1',
      )..createSync(recursive: true);
      _writeDataJsonWithTemplateId(resp1, templateId, [
        {'dataKey': 'r101', 'answer': 'Alice'},
      ]);

      final resp2 = Directory(
        '${tempDir.path}/session-1/answers/resp-B/assign1/section1',
      )..createSync(recursive: true);
      _writeDataJsonWithTemplateId(resp2, templateId, [
        {'dataKey': 'r101', 'answer': 'Bob'},
      ]);

      final result = await reader.loadRecords(tempDir, _testTemplate());

      expect(result.records.length, 2);
      final names = result.records.map((r) => r['r101']).toSet();
      expect(names, containsAll(['Alice', 'Bob']));
      expect(result.meta.map((m) => m.respUuid).toSet(), {'resp-A', 'resp-B'});
    });

    test('session format: filters out records with wrong templateId', () async {
      final resp1 = Directory(
        '${tempDir.path}/session-2/answers/resp-C/assign1/section1',
      )..createSync(recursive: true);
      _writeDataJsonWithTemplateId(resp1, 'test-uuid', [
        {'dataKey': 'r101', 'answer': 'Charlie'},
      ]);

      final resp2 = Directory(
        '${tempDir.path}/session-2/answers/resp-D/assign1/section1',
      )..createSync(recursive: true);
      _writeDataJsonWithTemplateId(resp2, 'other-template-uuid', [
        {'dataKey': 'r101', 'answer': 'Dave'},
      ]);

      final result = await reader.loadRecords(tempDir, _testTemplate());

      expect(result.records.length, 1);
      expect(result.records.first['r101'], 'Charlie');
    });

    test('session format: two sessions with one respondent each', () async {
      const templateId = 'test-uuid';
      for (final session in ['session-X', 'session-Y']) {
        final dir = Directory(
          '${tempDir.path}/$session/answers/resp-Z$session/a1/s1',
        )..createSync(recursive: true);
        _writeDataJsonWithTemplateId(dir, templateId, [
          {'dataKey': 'r101', 'answer': session},
        ]);
      }

      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records.length, 2);
    });
  });
}

FasihTemplate _testTemplate() => FasihTemplate.fromJson(
      'test-uuid',
      jsonEncode({
        'title': 'Test Survey',
        'dataKey': 'test',
        'components': [
          [
            {'type': 25, 'dataKey': 'r101', 'label': 'Q1'},
            {'type': 25, 'dataKey': 'r102', 'label': 'Q2'},
            {'type': 25, 'dataKey': 'r201', 'label': 'Q3'},
          ],
        ],
      }),
    );

void _writeDataJson(Directory dir, List<Map<String, dynamic>> answers) {
  File('${dir.path}/data.json')
      .writeAsStringSync(jsonEncode({'answers': answers}));
}

void _writeDataJsonWithTemplateId(
  Directory dir,
  String templateId,
  List<Map<String, dynamic>> answers,
) {
  File('${dir.path}/data.json').writeAsStringSync(
    jsonEncode({'templateId': templateId, 'answers': answers}),
  );
}
