import 'dart:convert';
import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/values/strings.dart';
import '../models/fasih_record.dart';
import '../models/fasih_template.dart';

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

  Future<List<FasihRecord>> loadRecords(
    Directory backupDir,
    FasihTemplate template,
  ) async {
    final records = <FasihRecord>[];

    await for (final entry in backupDir.list()) {
      if (entry is! Directory) continue;
      if (_skipDirs.contains(p.basename(entry.path))) continue;

      final dataFiles = await _findDataFiles(entry);
      for (final dataFile in dataFiles) {
        final record = await _parseDataFile(dataFile);
        if (record != null) records.add(record);
      }
    }

    return records;
  }

  Future<List<File>> _findDataFiles(Directory dir) async {
    final results = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || p.basename(entity.path) != 'data.json') continue;
      results.add(entity);
    }
    return results;
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
