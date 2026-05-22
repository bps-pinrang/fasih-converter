import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';
import 'package:json_converter/app/data/models/respondent_load_result.dart';

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
        final dir = Directory('${tempDir.path}/$skip/answers/q1')
          ..createSync(recursive: true);
        _writeDataJson(dir, [
          {'dataKey': 'r101', 'answer': 'should not appear'},
        ]);
      }
      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
    });

    test('parses respondent data.json answers', () async {
      final respDir = Directory('${tempDir.path}/respondent-uuid-1/answers/q1')
        ..createSync(recursive: true);
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
      expect(result.meta.first.questionUuid, 'q1');
    });

    test('handles array-type answers', () async {
      final respDir = Directory('${tempDir.path}/resp-2/answers/q1')
        ..createSync(recursive: true);
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
      final respDir = Directory('${tempDir.path}/resp-bad/answers/q1')
        ..createSync(recursive: true);
      File('${respDir.path}/data.json').writeAsStringSync('not valid json');

      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
    });

    test('silently skips data.json without answers key', () async {
      final respDir = Directory('${tempDir.path}/resp-empty/answers/q1')
        ..createSync(recursive: true);
      File('${respDir.path}/data.json')
          .writeAsStringSync(jsonEncode({'other': 'data'}));

      final result = await reader.loadRecords(tempDir, _testTemplate());
      expect(result.records, isEmpty);
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
