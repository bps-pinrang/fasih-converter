import 'package:gsheets/gsheets.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';

class FasihConverterSheetApi {
  static GSheets? _gSheets;
  static Worksheet? _sheet;

  static Future<void> init(String sheetTitle) async {
    final repo = SettingsRepository.instance;
    final credentials = repo.credentialsJson;
    final sheetId = repo.sheetId;

    if (credentials == null || sheetId == null) {
      throw Exception(
        'Google Sheets belum dikonfigurasi.\nBuka Pengaturan terlebih dahulu.',
      );
    }

    _gSheets = GSheets(credentials);
    final spreadsheet = await _gSheets!.spreadsheet(sheetId);
    _sheet = spreadsheet.worksheetByTitle(sheetTitle) ??
        await spreadsheet.addWorksheet(sheetTitle);
  }

  static Future<void> appendRows(
    List<Map<String, dynamic>> rows,
    List<String> headers,
  ) async {
    if (_sheet == null) throw Exception('Sheet belum diinisialisasi.');
    await _sheet!.values.insertRow(1, headers);
    await _sheet!.values.map.appendRows(rows);
  }

  static void dispose() {
    _sheet = null;
    _gSheets = null;
  }
}
