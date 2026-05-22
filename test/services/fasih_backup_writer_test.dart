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
        rawDataJson: '{"respondentId":"resp-1"}',
      ),
      RespondentMeta(
        respUuid: 'resp-2',
        answersRelPath: 'q1/section1/item2',
        rawDataJson: '{"respondentId":"resp-2"}',
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

    test('meta sheet col C stores envelope JSON without answers key', () {
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: template,
        records: records,
        respondentMeta: meta,
        envJson: '[]',
      );
      final metaSheet = workbook.worksheets[1];
      final storedJson = metaSheet.getRangeByIndex(7, 3).getText() ?? '';
      final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
      expect(decoded.containsKey('answers'), isFalse);
      expect(decoded['respondentId'], 'resp-1');
      workbook.dispose();
    });

    test('data sheet name is truncated to Excel 31-char limit', () {
      // Excel rejects sheet names longer than 31 characters.
      final longTemplate = FasihTemplate.fromJson(
        'tpl-long-uuid',
        jsonEncode({
          'title': 'Long Survey',
          'dataKey': 'PODES2024-DESA-FF-extra-suffix-that-overflows',
          'components': [
            [
              {'type': 25, 'dataKey': 'r101', 'label': 'Q1'},
            ],
          ],
        }),
      );
      final writer = FasihBackupWriter();
      final workbook = writer.buildWorkbook(
        template: longTemplate,
        records: const [],
        respondentMeta: const [],
        envJson: '[]',
      );
      expect(workbook.worksheets[0].name.length, lessThanOrEqualTo(31));
      expect(
        workbook.worksheets[0].name,
        'PODES2024-DESA-FF-extra-suffix-'.substring(0, 31),
      );
      workbook.dispose();
    });
  });

  group('reconstructAnswerValue', () {
    test('returns empty string for empty input', () {
      expect(FasihBackupWriter.reconstructAnswerValue(''), '');
    });

    test('returns plain string unchanged', () {
      expect(FasihBackupWriter.reconstructAnswerValue('Ahmad'), 'Ahmad');
    });

    test('returns numeric string unchanged', () {
      expect(FasihBackupWriter.reconstructAnswerValue('35'), '35');
    });

    test('coerces single [value] label to list-of-map', () {
      final result = FasihBackupWriter.reconstructAnswerValue('[1] Laki-laki');
      expect(result, isA<List>());
      final list = result as List;
      expect(list, hasLength(1));
      expect(list[0], {'value': '1', 'label': 'Laki-laki'});
    });

    test('coerces multi-item [value] label pattern to list-of-maps', () {
      final result = FasihBackupWriter.reconstructAnswerValue(
        '[A] Pilihan A; [B] Pilihan B; [C] Pilihan C',
      );
      expect(result, isA<List>());
      final list = result as List;
      expect(list, hasLength(3));
      expect(list[0], {'value': 'A', 'label': 'Pilihan A'});
      expect(list[1], {'value': 'B', 'label': 'Pilihan B'});
      expect(list[2], {'value': 'C', 'label': 'Pilihan C'});
    });

    test('returns string unchanged when only some parts match pattern', () {
      // Mixed: one part matches, one does not — treat as plain string.
      final result =
          FasihBackupWriter.reconstructAnswerValue('[1] Valid; plain text');
      expect(result, '[1] Valid; plain text');
    });
  });
}
