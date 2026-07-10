import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/values/strings.dart';
import '../models/fasih_record.dart';
import '../models/fasih_template.dart';
import '../models/respondent_load_result.dart';
import 'fasih_backup_writer.dart';
import 'fasih_encryption_helper.dart';

@singleton
class FasihBackupReader {
  static const _skipDirs = {
    'Template',
    'env',
    'lookup',
    'formengine',
    'backup'
  };

  Future<Directory> extractZip(
    File zipFile, {
    void Function(int current, int total)? onProgress,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final name = p.basenameWithoutExtension(zipFile.path);
    final dest = Directory(p.join(appDir.path, name));
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);

    // Stream from disk entry-by-entry; never loads the full archive into RAM.
    final inputStream = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(inputStream);
      final total = archive.length;
      var current = 0;
      // Throttle to ~1% steps so we don't spam emit on large archives.
      final step = (total / 100).ceil().clamp(1, total.clamp(1, total));
      var lastReported = 0;

      for (final entry in archive) {
        final entryPath = _sanitizePath(entry.name);
        if (entryPath == null) {
          current++;
          continue;
        }
        if (entry.isFile) {
          final outFile = File(p.join(dest.path, entryPath));
          await outFile.parent.create(recursive: true);
          final outStream = OutputFileStream(outFile.path);
          try {
            entry.writeContent(outStream);
          } finally {
            await outStream.close();
          }
        }
        current++;
        if (onProgress != null &&
            (current == total || current - lastReported >= step)) {
          lastReported = current;
          onProgress(current, total);
        }
      }
      await archive.clear();
    } finally {
      await inputStream.close();
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

  /// Returns the set of survey-period UUIDs found in [backupDir].
  ///
  /// In v2.16.3 the layout is `{userUUID}/answers/{periodUUID}/…`, so the
  /// direct children of every `answers/` dir are period UUIDs.
  Future<Set<String>> discoverPeriodIds(Directory backupDir) async {
    final ids = <String>{};
    await for (final entry in backupDir.list()) {
      if (entry is! Directory) continue;
      if (_skipDirs.contains(p.basename(entry.path))) continue;
      final answersDir = Directory(p.join(entry.path, 'answers'));
      if (!await answersDir.exists()) continue;
      await for (final sub in answersDir.list()) {
        if (sub is Directory) ids.add(p.basename(sub.path));
      }
    }
    return ids;
  }

  /// Loads records for [template] from [backupDir].
  ///
  /// When [onRecord] is provided each parsed record/meta pair is delivered via
  /// callback as soon as it is ready; the returned [RespondentLoadResult] will
  /// have empty [records] and [meta] lists (the caller owns accumulation).
  /// When [onRecord] is null, accumulation happens here and the full lists are
  /// returned in the result.
  Future<RespondentLoadResult> loadRecords(
    Directory backupDir,
    FasihTemplate template, {
    void Function(int loaded, int total)? onProgress,
    void Function(FasihRecord record, RespondentMeta meta)? onRecord,
    Map<String, String> wrappedDataKeys = const {},
  }) async {
    final records = onRecord != null ? null : <FasihRecord>[];
    final meta = onRecord != null ? null : <RespondentMeta>[];
    var loadedCount = 0;

    // First pass: collect all respondent tasks so we know the total upfront.
    final tasks =
        <({String respUuid, Directory searchDir, Directory answersBaseDir})>[];

    await for (final entry in backupDir.list()) {
      if (entry is! Directory) continue;
      if (_skipDirs.contains(p.basename(entry.path))) continue;

      final answersDir = Directory(p.join(entry.path, 'answers'));
      if (!await answersDir.exists()) continue;

      if (await _isSessionFormat(answersDir)) {
        // New format: <sessionUUID>/answers/<respUUID>/...
        await for (final respEntry in answersDir.list()) {
          if (respEntry is! Directory) continue;
          tasks.add((
            respUuid: p.basename(respEntry.path),
            searchDir: respEntry,
            answersBaseDir: respEntry,
          ));
        }
      } else {
        // Old format: <respUUID>/answers/...
        tasks.add((
          respUuid: p.basename(entry.path),
          searchDir: answersDir,
          answersBaseDir: answersDir,
        ));
      }
    }

    // Second pass: process each task, firing onProgress after every record.
    // Total is reported as 0 (indeterminate) because tasks.length equals
    // top-level directories — in old-format backups one directory can yield
    // many respondents, so using it as a total would show values > 100%.
    for (final t in tasks) {
      await _loadRespondent(
        respUuid: t.respUuid,
        searchDir: t.searchDir,
        answersBaseDir: t.answersBaseDir,
        template: template,
        records: records,
        meta: meta,
        onRecord: onRecord,
        wrappedDataKeys: wrappedDataKeys,
        onRecordAdded:
            onProgress != null ? () => onProgress(++loadedCount, 0) : null,
      );
    }

    final envFile = File(
      p.join(backupDir.path, 'env', 'assignment_listing.json'),
    );
    final envJson =
        await envFile.exists() ? await envFile.readAsString() : '[]';

    return RespondentLoadResult(
      records: records ?? [],
      meta: meta ?? [],
      envJson: envJson,
    );
  }

  Future<bool> _isSessionFormat(Directory answersDir) async {
    await for (final entity in answersDir.list(recursive: true)) {
      if (entity is! File || p.basename(entity.path) != 'data.json') continue;
      try {
        final raw = await entity.readAsString();
        final map = await _decodeJson(raw);
        if (map == null) continue; // encrypted — try next file
        final tid = map[kColumnTemplateId];
        return tid != null && (tid as String).isNotEmpty;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<void> _loadRespondent({
    required String respUuid,
    required Directory searchDir,
    required Directory answersBaseDir,
    required FasihTemplate template,
    List<FasihRecord>? records,
    List<RespondentMeta>? meta,
    void Function(FasihRecord, RespondentMeta)? onRecord,
    void Function()? onRecordAdded,
    Map<String, String> wrappedDataKeys = const {},
  }) async {
    final fieldKeys = template.fields.map((f) => f.dataKey).toSet();
    await for (final entity in searchDir.list(recursive: true)) {
      if (entity is! File || p.basename(entity.path) != 'data.json') continue;
      final relPath = p.relative(entity.parent.path, from: answersBaseDir.path);
      final rawJson = await entity.readAsString();
      // In v2.16.3 the path is …/answers/{periodUUID}/{blockUUID}/{respUUID}/data.json;
      // blockUUID == regionId used as the wrappedDataKeys lookup key.
      final blockUuid = p.basename(entity.parent.parent.path);
      final wrappedDataKey = wrappedDataKeys[blockUuid];
      final map = await _decodeJson(rawJson, wrappedDataKey: wrappedDataKey);
      if (map == null) continue;

      // Only read reference.json when data.json is missing field keys.
      // For surveys where data.json covers everything (e.g. SAK), this skips
      // the 1.9 MB file read entirely.
      final dataKeys = _extractAnswerKeys(map);
      final missingKeys =
          fieldKeys.isEmpty ? <String>{} : fieldKeys.difference(dataKeys);

      Map<String, dynamic>? referenceMap;
      if (missingKeys.isNotEmpty) {
        final refFile = File(p.join(entity.parent.path, 'reference.json'));
        if (await refFile.exists()) {
          referenceMap = parseReferenceJson(
            await refFile.readAsString(),
            onlyKeys: missingKeys,
          );
        }
      }

      final parsed = _recordFromMap(
        map,
        templateId: template.id,
        templateDataKey: template.dataKey,
        fieldKeys: fieldKeys,
        referenceMap: referenceMap,
      );
      if (parsed == null) continue;

      final envelope = Map<String, dynamic>.from(map)..remove(kColumnAnswers);
      final metaEntry = RespondentMeta(
        respUuid: respUuid,
        answersRelPath: relPath,
        rawDataJson: jsonEncode(envelope),
      );

      if (onRecord != null) {
        onRecord(parsed, metaEntry);
      } else {
        records!.add(parsed);
        meta!.add(metaEntry);
      }
      onRecordAdded?.call();
    }
  }

  /// Extracts the set of dataKey values from a data.json answer list.
  Set<String> _extractAnswerKeys(Map<String, dynamic> map) {
    final answersRaw = map[kColumnAnswers];
    if (answersRaw is! List) return {};
    final keys = <String>{};
    for (final item in answersRaw) {
      if (item is! Map<String, dynamic>) continue;
      final key = item[kColumnDataKey] as String?;
      if (key != null) keys.add(key);
    }
    return keys;
  }

  /// Parses a reference.json string into a {dataKey: answer} map.
  ///
  /// When [onlyKeys] is provided, only entries whose dataKey is in the set are
  /// included — avoids building a large map when only a subset is needed.
  /// Returns an empty map on any error or missing/invalid content.
  @visibleForTesting
  static Map<String, dynamic> parseReferenceJson(
    String raw, {
    Set<String>? onlyKeys,
  }) {
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final details = root['details'];
      if (details is! List) return {};
      final result = <String, dynamic>{};
      for (final item in details) {
        if (item is! Map<String, dynamic>) continue;
        final key = item['dataKey'] as String?;
        if (key == null || key.isEmpty) continue;
        if (onlyKeys != null && !onlyKeys.contains(key)) continue;
        final answer = item['answer'];
        if (answer == null) continue;
        if (answer is String && answer.isEmpty) continue;
        result[key] = answer;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Parses [raw] as JSON, transparently decrypting if needed.
  /// Returns null when the content is unreadable.
  Future<Map<String, dynamic>?> _decodeJson(
    String raw, {
    String? wrappedDataKey,
  }) async {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final decrypted = FasihEncryptionHelper.tryDecrypt(
        raw,
        wrappedDataKey: wrappedDataKey,
      );
      if (decrypted == null) return null;
      try {
        return jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  FasihRecord? _recordFromMap(
    Map<String, dynamic> map, {
    String? templateId,
    String? templateDataKey,
    Set<String>? fieldKeys,
    Map<String, dynamic>? referenceMap,
  }) {
    try {
      // Reject if the file declares a templateId/dataKey that does not match.
      // Files with neither field present are accepted (legacy backups) but are
      // subject to the cross-template key-overlap guard below.
      final fileTemplateId = map[kColumnTemplateId] as String?;
      final fileDataKey = map[kColumnTemplateDataKey] as String?;
      final isLegacy = (fileTemplateId == null || fileTemplateId.isEmpty) &&
          (fileDataKey == null || fileDataKey.isEmpty);
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

      // Fill gaps from reference.json (data.json always wins).
      if (referenceMap != null) {
        for (final entry in referenceMap.entries) {
          if (!values.containsKey(entry.key)) {
            values[entry.key] = FasihRecord.extractAnswer(entry.value);
          }
        }
      }

      // Cross-template guard: only for legacy records (no declared templateId /
      // templateDataKey). Require that at least 20 % of the record's answer
      // keys are recognised field keys of this template.  A single shared
      // generic key (prov / kab / desa) is not sufficient — it would
      // incorrectly accept records from co-active surveys (e.g. SE2026,
      // VHTS) whose location fields happen to overlap with this template.
      if (isLegacy &&
          fieldKeys != null &&
          fieldKeys.isNotEmpty &&
          values.isNotEmpty) {
        final matchCount = values.keys.where(fieldKeys.contains).length;
        final minMatch = (values.length * 0.20).ceil();
        if (matchCount < minMatch) return null;
      }

      return FasihRecord(values);
    } catch (_) {
      return null;
    }
  }

  /// Public wrapper for testing the record-building logic.
  @visibleForTesting
  static FasihRecord? buildRecordFromMaps(
    Map<String, dynamic> dataMap, {
    Map<String, dynamic>? referenceMap,
    String? templateId,
    String? templateDataKey,
    Set<String>? fieldKeys,
  }) {
    return FasihBackupReader()._recordFromMap(
      dataMap,
      templateId: templateId,
      templateDataKey: templateDataKey,
      fieldKeys: fieldKeys,
      referenceMap: referenceMap,
    );
  }
}
