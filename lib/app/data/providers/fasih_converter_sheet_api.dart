import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:gsheets/gsheets.dart';
import 'package:json_converter/app/data/core/values/strings.dart';
import 'package:json_converter/app/data/models/art_fields.dart';
import 'package:json_converter/app/data/models/ruta_fields.dart';

class FasihConverterSheetApi {
  static late String _credentials;
  static late String _sheetId;

  static late final GSheets _gSheets;

  static Worksheet? _artSheet;
  static Worksheet? _rutaSheet;

  static Future init() async {
    try {
      _credentials = await rootBundle.loadString('assets/credentials/fasih-converter.json');
      print('credentials');
      _gSheets = GSheets(_credentials);
      _sheetId =  FlutterConfig.get(kEnvKeyGoogleSheetId);
      final rutaTitle =  FlutterConfig.get(kEnvKeyRutaSheetTitle);
      final artTitle =  FlutterConfig.get(kEnvKeyArtSheetTitle);
      final spreadSheet = await _gSheets.spreadsheet(_sheetId);
      _artSheet = await _getWorkSheet(spreadSheet, title: artTitle);
      final artColumns = ARTFields().getFields();
      _artSheet!.values.insertRow(1, artColumns);
      _rutaSheet = await _getWorkSheet(spreadSheet, title: rutaTitle);
      final rutaColumns = RutaFields().getFields();
      _rutaSheet!.values.insertRow(1, rutaColumns);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  static Future<Worksheet?> _getWorkSheet(Spreadsheet spreadsheet,
      {required String title}) async {
    try {
      return await spreadsheet.addWorksheet(title);
    } catch (e) {
      return spreadsheet.worksheetByTitle(title);
    }
  }

  static Future insertRuta(List<Map<String, dynamic>> rows) async {
    if (_rutaSheet == null) {
      throw Exception('Gagal melakukan insert!\nSheet tidak ditemukan!');
    }
    _rutaSheet!.values.map.appendRows(rows);
  }

  static Future insertART(List<Map<String, dynamic>> rows) async {
    if (_artSheet == null) {
      throw Exception('Gagal melakukan insert!\nSheet tidak ditemukan!');
    }
    _artSheet!.values.map.appendRows(rows);
  }
}
