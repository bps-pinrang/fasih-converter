import 'dart:convert';
import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/values/strings.dart';
import '../models/fasih_record.dart';
import '../models/fasih_template.dart';
import '../models/respondent_load_result.dart';
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
    final dest = Directory('${appDir.path}/$name');
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);
    await ZipFile.extractToDirectory(
      zipFile: zipFile,
      destinationDir: dest,
    );
    return dest;
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
      templates.add(FasihTemplate.fromJson(uuid, content));
    }
    return templates;
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

      final respUuid = p.basename(entry.path);
      final answersDir = Directory(p.join(entry.path, 'answers'));
      if (!await answersDir.exists()) continue;

      await for (final questionEntry in answersDir.list()) {
        if (questionEntry is! Directory) continue;
        final questionUuid = p.basename(questionEntry.path);
        final dataFile = File(p.join(questionEntry.path, 'data.json'));
        if (!await dataFile.exists()) continue;

        final rawJson = await dataFile.readAsString();
        final record = await _parseDataFile(dataFile);
        if (record == null) continue;

        records.add(record);
        meta.add(RespondentMeta(
          respUuid: respUuid,
          questionUuid: questionUuid,
          rawDataJson: rawJson,
        ));
      }
    }

    final envFile = File(
      p.join(backupDir.path, 'env', 'assignment_listing.json'),
    );
    final envJson =
        await envFile.exists() ? await envFile.readAsString() : '[]';

    return RespondentLoadResult(records: records, meta: meta, envJson: envJson);
  }

  Future<FasihRecord?> _parseDataFile(File file) async {
    try {
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final answersRaw = map[kColumnAnswers];
      if (answersRaw is! List) return null;

      final values = <String, String>{};
      for (final item in answersRaw) {
        if (item is! Map<String, dynamic>) continue;
        final key = item[kColumnDataKey] as String?;
        if (key == null) continue;
        values[key] = FasihRecord.extractAnswer(item[kColumnAnswer]);
      }
      return FasihRecord(values);
    } catch (_) {
      return null;
    }
  }
}
