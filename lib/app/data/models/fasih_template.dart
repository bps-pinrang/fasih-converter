import 'dart:convert';

const _skipTypes = {1, 3};

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

  const FasihTemplate({
    required this.id,
    required this.title,
    required this.dataKey,
    required this.fields,
  });

  static FasihTemplate fromJson(String id, String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final fields = <FasihTemplateField>[];
    _extractFields(map['components'] as List<dynamic>? ?? [], fields);
    return FasihTemplate(
      id: id,
      title: (map['title'] as String?) ?? id,
      dataKey: (map['dataKey'] as String?) ?? id,
      fields: fields,
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
        final label = rawLabel.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        out.add(FasihTemplateField(dataKey: dataKey, label: label, type: type));
      }
    }
  }
}
