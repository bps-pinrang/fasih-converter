import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_archive/flutter_archive.dart' as flutter_archive;
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

  List<int> buildBytes({
    required FasihTemplate template,
    required List<FasihRecord> records,
    required List<RespondentMeta> respondentMeta,
    required String envJson,
  }) {
    final wb = buildWorkbook(
      template: template,
      records: records,
      respondentMeta: respondentMeta,
      envJson: envJson,
    );
    final raw = wb.saveAsStream();
    wb.dispose();
    return _patchXlsx(raw);
  }

  /// Post-processes the raw XLSX bytes from Syncfusion xlsio to fix two issues:
  /// 1. Missing xl/theme/theme1.xml (causes Excel "repair" prompt).
  /// 2. t-elements in sharedStrings.xml without xml:space="preserve" on
  ///    strings with leading/trailing whitespace (causes string corruption).
  List<int> _patchXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final hasTheme = archive.any((f) => f.name == 'xl/theme/theme1.xml');

    final patched = Archive();
    for (final file in archive) {
      if (!hasTheme && file.name == '[Content_Types].xml') {
        final content = utf8.decode(file.content as List<int>);
        final updated = content.replaceFirst(
          '</Types>',
          '<Override PartName="/xl/theme/theme1.xml"'
              ' ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
              '</Types>',
        );
        final data = utf8.encode(updated);
        patched.addFile(ArchiveFile('[Content_Types].xml', data.length, data));
      } else if (!hasTheme && file.name == 'xl/_rels/workbook.xml.rels') {
        final content = utf8.decode(file.content as List<int>);
        final updated = content.replaceFirst(
          '</Relationships>',
          '<Relationship Id="rId_theme"'
              ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"'
              ' Target="theme/theme1.xml"/>'
              '</Relationships>',
        );
        final data = utf8.encode(updated);
        patched.addFile(
          ArchiveFile('xl/_rels/workbook.xml.rels', data.length, data),
        );
      } else if (file.name == 'xl/sharedStrings.xml') {
        // OOXML requires xml:space="preserve" on <t> elements whose text has
        // leading or trailing whitespace. Syncfusion never adds it, so Excel
        // strips the whitespace and reports a repair. Adding it to every <t>
        // is safe — parsers ignore it when the content has no whitespace.
        final content = utf8.decode(file.content as List<int>);
        final updated = content.replaceAll('<t>', '<t xml:space="preserve">');
        final data = utf8.encode(updated);
        patched.addFile(
          ArchiveFile('xl/sharedStrings.xml', data.length, data),
        );
      } else {
        patched.addFile(file);
      }
    }

    if (!hasTheme) {
      final themeData = utf8.encode(_minimalThemeXml);
      patched.addFile(
        ArchiveFile('xl/theme/theme1.xml', themeData.length, themeData),
      );
    }

    return ZipEncoder().encode(patched);
  }

  static const _minimalThemeXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">'
      '<a:themeElements>'
      '<a:clrScheme name="Office">'
      '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
      '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
      '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
      '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
      '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
      '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
      '<a:accent3><a:srgbClr val="A9D18E"/></a:accent3>'
      '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
      '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
      '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
      '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
      '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
      '</a:clrScheme>'
      '<a:fontScheme name="Office">'
      '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
      '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
      '</a:fontScheme>'
      '<a:fmtScheme name="Office">'
      '<a:fillStyleLst>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:gradFill rotWithShape="1"><a:gsLst>'
      '<a:gs pos="0"><a:schemeClr val="phClr"><a:lumMod val="110000"/><a:satMod val="105000"/><a:tint val="67000"/></a:schemeClr></a:gs>'
      '<a:gs pos="50000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="103000"/><a:tint val="73000"/></a:schemeClr></a:gs>'
      '<a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="109000"/><a:tint val="81000"/></a:schemeClr></a:gs>'
      '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>'
      '<a:gradFill rotWithShape="1"><a:gsLst>'
      '<a:gs pos="0"><a:schemeClr val="phClr"><a:satMod val="103000"/><a:lumMod val="102000"/><a:tint val="94000"/></a:schemeClr></a:gs>'
      '<a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="99000"/><a:satMod val="120000"/><a:shade val="78000"/></a:schemeClr></a:gs>'
      '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>'
      '</a:fillStyleLst>'
      '<a:lnStyleLst>'
      '<a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>'
      '<a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>'
      '<a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>'
      '</a:lnStyleLst>'
      '<a:effectStyleLst>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst>'
      '<a:outerShdw blurRad="57150" dist="19050" dir="5400000" algn="ctr" rotWithShape="0">'
      '<a:srgbClr val="000000"><a:alpha val="63000"/></a:srgbClr>'
      '</a:outerShdw>'
      '</a:effectLst></a:effectStyle>'
      '</a:effectStyleLst>'
      '<a:bgFillStyleLst>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:solidFill><a:schemeClr val="phClr"><a:tint val="95000"/><a:satMod val="170000"/></a:schemeClr></a:solidFill>'
      '<a:gradFill rotWithShape="1"><a:gsLst>'
      '<a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="93000"/><a:satMod val="150000"/><a:shade val="98000"/><a:lumMod val="102000"/></a:schemeClr></a:gs>'
      '<a:gs pos="50000"><a:schemeClr val="phClr"><a:tint val="98000"/><a:lumMod val="102000"/><a:satMod val="130000"/></a:schemeClr></a:gs>'
      '<a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="63000"/><a:satMod val="120000"/></a:schemeClr></a:gs>'
      '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>'
      '</a:bgFillStyleLst>'
      '</a:fmtScheme>'
      '</a:themeElements>'
      '</a:theme>';

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
      await flutter_archive.ZipFile.createFromDirectory(
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
    final name = template.dataKey;
    sheet.name = name.length > 31 ? name.substring(0, 31) : name;

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
