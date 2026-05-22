import 'dart:convert';

class BackupHistoryEntry {
  final String dirPath;
  final String templateId;
  final String templateTitle;
  final String zipName;
  final int zipSize;
  final DateTime loadedAt;

  const BackupHistoryEntry({
    required this.dirPath,
    required this.templateId,
    required this.templateTitle,
    required this.zipName,
    required this.zipSize,
    required this.loadedAt,
  });

  factory BackupHistoryEntry.fromJson(Map<String, dynamic> json) =>
      BackupHistoryEntry(
        dirPath: json['dirPath'] as String,
        templateId: json['templateId'] as String,
        templateTitle: (json['templateTitle'] as String?) ?? '',
        zipName: json['zipName'] as String,
        zipSize: (json['zipSize'] as int?) ?? 0,
        loadedAt: DateTime.parse(json['loadedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'dirPath': dirPath,
        'templateId': templateId,
        'templateTitle': templateTitle,
        'zipName': zipName,
        'zipSize': zipSize,
        'loadedAt': loadedAt.toIso8601String(),
      };

  static List<BackupHistoryEntry> listFromJsonString(String raw) {
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(BackupHistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
