class FasihRecord {
  final Map<String, String> values;

  const FasihRecord(this.values);

  String operator [](String key) => values[key] ?? '';

  static String extractAnswer(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is List) {
      if (raw.isEmpty) return '';
      return raw.map((e) {
        if (e is Map<String, dynamic>) {
          final v = e['value']?.toString() ?? '';
          final l = e['label']?.toString() ?? '';
          return '[$v] $l';
        }
        return e.toString();
      }).join('; ');
    }
    return raw.toString();
  }
}
