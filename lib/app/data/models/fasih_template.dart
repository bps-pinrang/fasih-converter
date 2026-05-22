import 'dart:convert';

const _skipTypes = {1, 3};

class FasihValidationTest {
  final String test;
  final String message;
  final int type;

  const FasihValidationTest({
    required this.test,
    required this.message,
    required this.type,
  });
}

class FasihValidationRule {
  final String dataKey;
  final List<String> componentValidation;
  final List<FasihValidationTest> validations;

  const FasihValidationRule({
    required this.dataKey,
    required this.componentValidation,
    required this.validations,
  });
}

class FasihTemplateField {
  final String dataKey;
  final String label;
  final int type;

  const FasihTemplateField({
    required this.dataKey,
    required this.label,
    required this.type,
  });
}

class FasihTemplate {
  final String id;
  final String title;
  final String dataKey;
  final List<FasihTemplateField> fields;
  final String rawJson;
  final List<FasihValidationRule> validationRules;

  const FasihTemplate({
    required this.id,
    required this.title,
    required this.dataKey,
    required this.fields,
    required this.rawJson,
    this.validationRules = const [],
  });

  FasihTemplate withValidationRules(List<FasihValidationRule> rules) =>
      FasihTemplate(
        id: id,
        title: title,
        dataKey: dataKey,
        fields: fields,
        rawJson: rawJson,
        validationRules: rules,
      );

  static FasihTemplate fromJson(String id, String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final fields = <FasihTemplateField>[];
    _extractFields(map['components'] as List<dynamic>? ?? [], fields);
    return FasihTemplate(
      id: id,
      title: (map['title'] as String?) ?? id,
      dataKey: (map['dataKey'] as String?) ?? id,
      fields: fields,
      rawJson: jsonStr,
    );
  }

  static void _extractFields(
    List<dynamic> components,
    List<FasihTemplateField> out,
  ) {
    for (final group in components) {
      if (group is! List) continue;
      for (final component in group) {
        if (component is! Map<String, dynamic>) continue;
        final type = (component['type'] as num?)?.toInt() ?? 0;
        final dataKey = component['dataKey'] as String?;
        if (component.containsKey('components')) {
          _extractFields(
            component['components'] as List<dynamic>,
            out,
          );
        }
        if (_skipTypes.contains(type) || dataKey == null || dataKey.isEmpty) {
          continue;
        }
        final rawLabel = (component['label'] as String?) ?? dataKey;
        final label = _cleanLabel(rawLabel);
        if (label.isEmpty || label == 'New Question') continue;
        out.add(FasihTemplateField(dataKey: dataKey, label: label, type: type));
      }
    }
  }

  static String _cleanLabel(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(r'$nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'\$[A-Z][A-Z0-9_]*\$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
