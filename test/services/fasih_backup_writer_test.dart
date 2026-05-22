import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/services/fasih_backup_writer.dart';

void main() {
  late FasihTemplate template;
  late List<FasihRecord> records;
  late List<RespondentMeta> meta;

  setUp(() {
    template = FasihTemplate.fromJson(
      'tpl-uuid',
      jsonEncode({
        'title': 'Test Survey',
        'dataKey': 'test',
        'components': [
          [
            {'type': 25, 'dataKey': 'r101', 'label': 'Nama'},
            {'type': 25, 'dataKey': 'r102', 'label': 'Umur'},
          ],
        ],
      }),
    );
    records = [
      FasihRecord({'r101': 'Ahmad', 'r102': '35'}),
      FasihRecord({'r101': 'Budi', 'r102': '28'}),
    ];
    meta = [
      RespondentMeta(
        respUuid: 'resp-1',
        answersRelPath: 'q1/section1/item1',
        rawDataJson: '{"respondentId":"resp-1","answers":[]}',
      ),
      RespondentMeta(
        respUuid: 'resp-2',
        answersRelPath: 'q1/section1/item2',
        rawDataJson: '{"respondentId":"resp-2","answers":[]}',
      ),
    ];
  });

  group('buildWorkbook', () {
    test('creates workbook with two sheets', () {
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: template,
        records: records,
        respondentMeta: meta,
        envJson: '[]',
      );
      expect(workbook.worksheets.count, 2);
      workbook.dispose();
    });

    test('data sheet has correct header and row count', () {
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: template,
        records: records,
        respondentMeta: meta,
        envJson: '[]',
      );
      final sheet = workbook.worksheets[0];
      expect(sheet.getRangeByIndex(1, 1).getText(), 'Nama');
      expect(sheet.getRangeByIndex(1, 2).getText(), 'Umur');
      expect(sheet.getRangeByIndex(2, 1).getText(), 'Ahmad');
      expect(sheet.getRangeByIndex(3, 1).getText(), 'Budi');
      workbook.dispose();
    });

    test('meta sheet version cell is correct', () {
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: template,
        records: records,
        respondentMeta: meta,
        envJson: '[]',
      );
      final metaSheet = workbook.worksheets[1];
      expect(metaSheet.getRangeByIndex(1, 2).getText(), 'fasih_backup_v1');
      workbook.dispose();
    });

    test('meta sheet respondent rows match records count', () {
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: template,
        records: records,
        respondentMeta: meta,
        envJson: '[]',
      );
      final metaSheet = workbook.worksheets[1];
      expect(metaSheet.getRangeByIndex(7, 1).getText(), 'resp-1');
      expect(metaSheet.getRangeByIndex(8, 1).getText(), 'resp-2');
      workbook.dispose();
    });
  });
}
