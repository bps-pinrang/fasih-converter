import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../core/env/app_env.dart';
import '../models/fasih_record.dart';
import '../models/fasih_template.dart';

class RespondentMeta {
  final String respUuid;
  final String answersRelPath;
  final String rawDataJson;

  const RespondentMeta({
    required this.respUuid,
    required this.answersRelPath,
    required this.rawDataJson,
  });
}

@singleton
class FasihBackupWriter {
  xlsio.Workbook buildWorkbook({
    required FasihTemplate template,
    required List<FasihRecord> records,
    required List<RespondentMeta> respondentMeta,
    required String envJson,
  }) {
    final workbook = xlsio.Workbook();
    _buildDataSheet(workbook, template, records);
    _buildMetaSheet(workbook, template, respondentMeta, envJson);
    return workbook;
  }

  Future<File> buildBackupZip({
    required xlsio.Workbook workbook,
    required FasihTemplate template,
    required List<FasihRecord> editedRecords,
    required String outputName,
  }) async {
    final metaSheet = workbook.worksheets[1];
    final tempDir = await Directory.systemTemp.createTemp('fasih_export_');

    try {
      // Reconstruct FASIH directory structure from metadata rows (row 7+)
      // Row layout: col A = respUuid, col B = questionUuid, col C = rawDataJson
      var row = 7;
      while (true) {
        final respUuid = metaSheet.getRangeByIndex(row, 1).getText() ?? '';
        if (respUuid.isEmpty) break;
        final answersRelPath =
            metaSheet.getRangeByIndex(row, 2).getText() ?? '';
        final rawDataJson = metaSheet.getRangeByIndex(row, 3).getText() ?? '{}';

        final dataDir = Directory(
          p.join(
            tempDir.path,
            respUuid,
            'answers',
            p.joinAll(answersRelPath.split('/')),
          ),
        );
        await dataDir.create(recursive: true);
        await File(p.join(dataDir.path, 'data.json'))
            .writeAsString(rawDataJson);

        row++;
      }

      final outputFile = await _resolveOutputFile(outputName);
      await ZipFile.createFromDirectory(
        sourceDir: tempDir,
        zipFile: outputFile,
        recurseSubDirs: true,
      );
      return outputFile;
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  void _buildDataSheet(
    xlsio.Workbook workbook,
    FasihTemplate template,
    List<FasihRecord> records,
  ) {
    final sheet = workbook.worksheets.innerList.first;
    sheet.name = template.dataKey;

    // Header row
    for (var i = 0; i < template.fields.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(template.fields[i].label);
    }

    // Data rows
    for (var r = 0; r < records.length; r++) {
      final record = records[r];
      for (var c = 0; c < template.fields.length; c++) {
        final key = template.fields[c].dataKey;
        sheet.getRangeByIndex(r + 2, c + 1).setText(record[key]);
      }
    }
  }

  void _buildMetaSheet(
    xlsio.Workbook workbook,
    FasihTemplate template,
    List<RespondentMeta> respondentMeta,
    String envJson,
  ) {
    final sheet = workbook.worksheets.addWithName('_fasih_meta');

    // Row 1: version
    sheet.getRangeByIndex(1, 1).setText('version');
    sheet.getRangeByIndex(1, 2).setText('fasih_backup_v1');

    // Row 2: template_uuid
    sheet.getRangeByIndex(2, 1).setText('template_uuid');
    sheet.getRangeByIndex(2, 2).setText(template.id);

    // Row 3: template_json
    sheet.getRangeByIndex(3, 1).setText('template_json');
    sheet.getRangeByIndex(3, 2).setText(template.rawJson);

    // Row 4: env_json
    sheet.getRangeByIndex(4, 1).setText('env_json');
    sheet.getRangeByIndex(4, 2).setText(envJson.isEmpty ? '{}' : envJson);

    // Row 5: blank separator

    // Row 6: respondent header
    sheet.getRangeByIndex(6, 1).setText('resp_uuid');
    sheet.getRangeByIndex(6, 2).setText('answers_rel_path');
    sheet.getRangeByIndex(6, 3).setText('raw_data_json');

    // Row 7+: one row per respondent
    for (var i = 0; i < respondentMeta.length; i++) {
      final m = respondentMeta[i];
      sheet.getRangeByIndex(7 + i, 1).setText(m.respUuid);
      sheet.getRangeByIndex(7 + i, 2).setText(m.answersRelPath);
      sheet.getRangeByIndex(7 + i, 3).setText(m.rawDataJson);
    }

    sheet.protect(AppEnv.fasihZipPassword);
  }

  Future<File> _resolveOutputFile(String name) async {
    final String dirPath;
    if (Platform.isAndroid) {
      dirPath = '/storage/emulated/0/Fasih Converter/Export';
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dirPath = '${docs.path}/Export';
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dirPath, name));
  }
}
