import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';

void main() {
  group('FasihTemplate.fromJson', () {
    test('extracts fields, skips labels and sections', () {
      const json = '''
      {
        "title": "Test Survey",
        "dataKey": "test",
        "components": [[
          {"type": 1, "dataKey": "section", "components": [[
            {"type": 3, "dataKey": "lbl", "label": "<b>Header</b>"},
            {"type": 25, "dataKey": "r101", "label": "Question 1"}
          ]]}
        ]]
      }
      ''';
      final template = FasihTemplate.fromJson('uuid-1', json);
      expect(template.title, 'Test Survey');
      expect(template.fields.length, 1);
      expect(template.fields.first.dataKey, 'r101');
      expect(template.fields.first.label, 'Question 1');
    });

    test('strips HTML tags from labels', () {
      const json = '''
      {
        "title": "T",
        "dataKey": "t",
        "components": [[
          {"type": 25, "dataKey": "f1", "label": "<div>Label</div>"}
        ]]
      }
      ''';
      final t = FasihTemplate.fromJson('id', json);
      expect(t.fields.first.label, 'Label');
    });
  });

  group('FasihRecord.extractAnswer', () {
    test('returns string answer as-is', () {
      expect(FasihRecord.extractAnswer('RIAU'), 'RIAU');
    });

    test('formats array answer as [value] label', () {
      final answer = [
        {'value': '14', 'label': 'RIAU'},
      ];
      expect(FasihRecord.extractAnswer(answer), '[14] RIAU');
    });

    test('joins multiple selections with semicolon', () {
      final answer = [
        {'value': '1', 'label': 'A'},
        {'value': '2', 'label': 'B'},
      ];
      expect(FasihRecord.extractAnswer(answer), '[1] A; [2] B');
    });

    test('returns empty string for null', () {
      expect(FasihRecord.extractAnswer(null), '');
    });

    test('sanitizes [object Object] to empty string', () {
      expect(FasihRecord.extractAnswer('[object Object]'), '');
    });
  });
}
