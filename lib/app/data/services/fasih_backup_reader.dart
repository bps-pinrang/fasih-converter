import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/values/strings.dart';
import '../models/fasih_record.dart';
import '../models/fasih_template.dart';
import '../models/respondent_load_result.dart';
import 'fasih_decryptor.dart';
import 'fasih_backup_writer.dart';

@singleton
class FasihBackupReader {
  static const _skipDirs = {
    'Template',
    'env',
    'lookup',
    'formengine',
    'backup'
  };

  Future<Directory> extractZip(File zipFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final name = p.basenameWithoutExtension(zipFile.path);
    final dest = Directory(p.join(appDir.path, name));
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final entryPath = _sanitizePath(entry.name);
      if (entryPath == null) continue;
      if (entry.isFile) {
        final outFile = File(p.join(dest.path, entryPath));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      }
    }
    return dest;
  }

  /// Normalises a ZIP entry name to a safe relative path.
  /// Returns null if the entry should be skipped (traversal or empty).
  String? _sanitizePath(String name) {
    var clean = name.replaceAll('\\', '/');
    // Strip leading slashes and ./ prefixes
    while (clean.startsWith('/') || clean.startsWith('./')) {
      clean = clean.startsWith('./') ? clean.substring(2) : clean.substring(1);
    }
    if (clean.isEmpty || clean.split('/').contains('..')) return null;
    return clean;
  }

  Future<List<FasihTemplate>> discoverTemplates(Directory backupDir) async {
    final templateDir = Directory(p.join(backupDir.path, 'Template'));
    if (!await templateDir.exists()) return [];

    final templates = <FasihTemplate>[];
    await for (final entry in templateDir.list()) {
      if (entry is! Directory) continue;
      final uuid = p.basename(entry.path);
      final jsonFile = File(p.join(entry.path, '${uuid}_template.json'));
      if (!await jsonFile.exists()) continue;
      final content = await jsonFile.readAsString();
      final template = FasihTemplate.fromJson(uuid, content);

      final validationFile =
          File(p.join(entry.path, '${uuid}_validation.json'));
      if (await validationFile.exists()) {
        final rules = _parseValidation(await validationFile.readAsString());
        templates.add(template.withValidationRules(rules));
      } else {
        templates.add(template);
      }
    }
    return templates;
  }

  List<FasihValidationRule> _parseValidation(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final funcs = map['testFunctions'] as List? ?? [];
      return funcs.map((f) {
        final comps = (f['componentValidation'] as List? ?? []).cast<String>();
        final tests = (f['validations'] as List? ?? [])
            .map(
              (v) => FasihValidationTest(
                test: v['test'] as String? ?? '',
                message: v['message'] as String? ?? '',
                type: v['type'] as int? ?? 0,
              ),
            )
            .toList();
        return FasihValidationRule(
          dataKey: f['dataKey'] as String? ?? '',
          componentValidation: comps,
          validations: tests,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RespondentLoadResult> loadRecords(
    Directory backupDir,
    FasihTemplate template,
  ) async {
    final records = <FasihRecord>[];
    final meta = <RespondentMeta>[];

    await for (final entry in backupDir.list()) {
      if (entry is! Directory) continue;
      if (_skipDirs.contains(p.basename(entry.path))) continue;

      final answersDir = Directory(p.join(entry.path, 'answers'));
      if (!await answersDir.exists()) continue;

      if (await _isSessionFormat(answersDir)) {
        // New format: <sessionUUID>/answers/<respUUID>/...
        await for (final respEntry in answersDir.list()) {
          if (respEntry is! Directory) continue;
          await _loadRespondent(
            respUuid: p.basename(respEntry.path),
            searchDir: respEntry,
            answersBaseDir: respEntry,
            template: template,
            records: records,
            meta: meta,
          );
        }
      } else {
        // Old format: <respUUID>/answers/...
        await _loadRespondent(
          respUuid: p.basename(entry.path),
          searchDir: answersDir,
          answersBaseDir: answersDir,
          template: template,
          records: records,
          meta: meta,
        );
      }
    }

    final envFile = File(
      p.join(backupDir.path, 'env', 'assignment_listing.json'),
    );
    final envJson =
        await envFile.exists() ? await envFile.readAsString() : '[]';

    return RespondentLoadResult(records: records, meta: meta, envJson: envJson);
  }

  Future<bool> _isSessionFormat(Directory answersDir) async {
    await for (final entity in answersDir.list(recursive: true)) {
      if (entity is! File || p.basename(entity.path) != 'data.json') continue;
      try {
        final raw = await entity.readAsString();
        final map = await _decodeJson(raw);
        if (map == null) return false;
        final tid = map[kColumnTemplateId];
        return tid != null && (tid as String).isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _loadRespondent({
    required String respUuid,
    required Directory searchDir,
    required Directory answersBaseDir,
    required FasihTemplate template,
    required List<FasihRecord> records,
    required List<RespondentMeta> meta,
  }) async {
    final fieldKeys = template.fields.map((f) => f.dataKey).toSet();
    await for (final entity in searchDir.list(recursive: true)) {
      if (entity is! File || p.basename(entity.path) != 'data.json') continue;
      final relPath = p.relative(entity.parent.path, from: answersBaseDir.path);
      final rawJson = await entity.readAsString();
      final parsed = await _parseDataFile(
        entity,
        templateId: template.id,
        templateDataKey: template.dataKey,
        fieldKeys: fieldKeys,
      );
      if (parsed == null) continue;
      records.add(parsed);
      meta.add(
        RespondentMeta(
          respUuid: respUuid,
          answersRelPath: relPath,
          rawDataJson: rawJson,
        ),
      );
    }
  }

  /// Parses [raw] as JSON, transparently decrypting if needed.
  /// Returns null when the content is unreadable.
  Future<Map<String, dynamic>?> _decodeJson(String raw) async {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final decrypted = FasihDecryptor.tryDecrypt(raw);
      if (decrypted == null) return null;
      try {
        return jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  Future<FasihRecord?> _parseDataFile(
    File file, {
    String? templateId,
    String? templateDataKey,
    Set<String>? fieldKeys,
  }) async {
    try {
      final raw = await file.readAsString();
      final map = await _decodeJson(raw);
      if (map == null) return null;

      // Reject if the file declares a templateId/dataKey that does not match.
      // Files with neither field present are accepted (legacy backups).
      final fileTemplateId = map[kColumnTemplateId] as String?;
      final fileDataKey = map[kColumnTemplateDataKey] as String?;
      if (fileTemplateId != null && fileTemplateId.isNotEmpty) {
        if (templateId != null && fileTemplateId != templateId) return null;
      } else if (fileDataKey != null && fileDataKey.isNotEmpty) {
        if (templateDataKey != null && fileDataKey != templateDataKey) {
          return null;
        }
      }

      final answersRaw = map[kColumnAnswers];
      if (answersRaw is! List) return null;

      final values = <String, String>{};
      for (final item in answersRaw) {
        if (item is! Map<String, dynamic>) continue;
        final key = item[kColumnDataKey] as String?;
        if (key == null) continue;
        values[key] = FasihRecord.extractAnswer(item[kColumnAnswer]);
      }

      // Cross-template guard: if the file has answers but none of its keys
      // match this template's fields, it belongs to a different survey.
      if (fieldKeys != null &&
          fieldKeys.isNotEmpty &&
          values.isNotEmpty &&
          !values.keys.any(fieldKeys.contains)) {
        return null;
      }

      return FasihRecord(values);
    } catch (_) {
      return null;
    }
  }
}
