import 'package:gsheets/gsheets.dart';
import 'package:injectable/injectable.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';

@singleton
class FasihConverterSheetApi {
  final SettingsRepository _settings;

  FasihConverterSheetApi(this._settings);

  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;

  Future<void> init(String sheetTitle) async {
    final creds = _settings.credentialsJson!;
    final sheetId = _settings.sheetId!;
    _gsheets = GSheets(creds);
    _spreadsheet = await _gsheets!.spreadsheet(sheetId);
    _worksheet = _spreadsheet!.worksheetByTitle(sheetTitle) ??
        await _spreadsheet!.addWorksheet(sheetTitle);
  }

  Future<void> appendRows(
    List<Map<String, dynamic>> rows,
    List<String> headers,
  ) async {
    if (_worksheet == null) throw StateError('Not initialized');
    final existing = await _worksheet!.values.allRows();
    if (existing.isEmpty) {
      await _worksheet!.values.insertRow(1, headers);
    }
    final serialized =
        rows.map((r) => headers.map((h) => '${r[h] ?? ''}').toList()).toList();
    await _worksheet!.values.appendRows(serialized);
  }

  void dispose() {
    _gsheets = null;
    _spreadsheet = null;
    _worksheet = null;
  }
}
