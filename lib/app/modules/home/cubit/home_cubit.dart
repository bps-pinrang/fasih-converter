import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../../data/core/utils/helpers.dart';
import 'home_side_effect.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final FasihBackupReader _reader;
  final SettingsRepository _settings;
  final FasihConverterSheetApi _sheetApi;

  final _sideEffectsController = StreamController<HomeSideEffect>.broadcast();
  Stream<HomeSideEffect> get sideEffects => _sideEffectsController.stream;

  String appVersion = '';
  Directory? _extractedDir;

  HomeCubit(this._reader, this._settings, this._sheetApi)
      : super(const HomeInitial()) {
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    appVersion = 'v${info.version}';
  }

  Future<void> pickAndLoadBackup() async {
    if (Platform.isAndroid) {
      var status = await perm.Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await perm.Permission.manageExternalStorage.request();
        if (!status.isGranted) return;
      }
    }

    emit(const HomeLoadingFile());
    _cleanup();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) {
        emit(const HomeInitial());
        return;
      }

      final path = result.files.first.path;
      if (path == null) {
        emit(const HomeInitial());
        return;
      }

      final file = result.files.first;
      _extractedDir = await _reader.extractZip(File(path));
      final templates = await _reader.discoverTemplates(_extractedDir!);

      if (templates.isEmpty) {
        _sideEffectsController.add(const ShowSnackbar(
          title: 'Template Tidak Ditemukan',
          message:
              'Backup ini tidak memiliki template survey yang dapat diproses.',
        ));
        emit(const HomeInitial());
        return;
      }

      if (templates.length == 1) {
        await _loadTemplate(file, templates.first);
      } else {
        emit(HomeMultiTemplate(file: file, templates: templates));
        _sideEffectsController.add(ShowTemplatePicker(templates));
      }
    } catch (e) {
      _sideEffectsController.add(ShowSnackbar(
        title: 'Kesalahan',
        message: e.toString(),
        isError: true,
      ));
      emit(const HomeInitial());
    }
  }

  Future<void> selectTemplate(FasihTemplate template) async {
    final current = state;
    if (current is! HomeMultiTemplate) return;
    emit(const HomeLoadingFile());
    await _loadTemplate(current.file, template);
  }

  Future<void> _loadTemplate(PlatformFile file, FasihTemplate template) async {
    try {
      final records = await _reader.loadRecords(_extractedDir!, template);
      emit(HomeFileLoaded(
        file: file,
        template: template,
        records: records,
      ));
    } catch (e) {
      _sideEffectsController.add(ShowSnackbar(
        title: 'Kesalahan',
        message: e.toString(),
        isError: true,
      ));
      emit(const HomeInitial());
    }
  }

  Future<void> exportToExcel() async {
    final current = state;
    if (current is! HomeFileLoaded) return;

    emit(current.copyWith(isExporting: true));
    try {
      final template = current.template;
      final headers = template.fields.map((f) => f.dataKey).toList();
      final labels = template.fields.map((f) => f.label).toList();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets.innerList.first;
      sheet.name = template.dataKey.length > 31
          ? template.dataKey.substring(0, 31)
          : template.dataKey;

      sheet.importList(labels, 1, 1, false);
      for (var i = 0; i < current.records.length; i++) {
        final row = headers.map((h) => current.records[i][h]).toList();
        sheet.importList(row, i + 2, 1, false);
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await createExportDir('Export');
      final fileName = '${p.basenameWithoutExtension(current.file.name)}.xlsx';
      final file = File(p.join(dir, fileName));
      await file.writeAsBytes(bytes);

      _sideEffectsController.add(const ShowSuccessDialog(
        title: 'Berhasil!',
        message: 'File Excel berhasil disimpan.',
      ));
    } catch (e) {
      _sideEffectsController.add(ShowSnackbar(
        title: 'Gagal Ekspor',
        message: e.toString(),
        isError: true,
      ));
    } finally {
      if (state is HomeFileLoaded) {
        emit((state as HomeFileLoaded).copyWith(isExporting: false));
      }
    }
  }

  Future<void> shareExcel() async {
    final current = state;
    if (current is! HomeFileLoaded) return;

    final dir = await createExportDir('Export');
    final fileName = '${p.basenameWithoutExtension(current.file.name)}.xlsx';
    final file = File(p.join(dir, fileName));
    if (!await file.exists()) {
      _sideEffectsController.add(const ShowSnackbar(
        title: 'File Tidak Ada',
        message: 'Ekspor terlebih dahulu.',
      ));
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: fileName);
  }

  Future<void> uploadToSheets() async {
    final current = state;
    if (current is! HomeFileLoaded) return;

    if (!_settings.isConfigured) {
      _sideEffectsController.add(const ShowSnackbar(
        title: 'Belum Dikonfigurasi',
        message: 'Buka Pengaturan dan isi credentials Google Sheets.',
      ));
      return;
    }

    emit(current.copyWith(isUploading: true));
    try {
      final template = current.template;
      final headers = template.fields.map((f) => f.dataKey).toList();
      final sheetTitle = template.dataKey.length > 100
          ? template.dataKey.substring(0, 100)
          : template.dataKey;

      await _sheetApi.init(sheetTitle);
      final rows = current.records
          .map((r) => {for (final h in headers) h: r[h]})
          .toList();
      await _sheetApi.appendRows(rows, headers);

      _sideEffectsController.add(const ShowSuccessDialog(
        title: 'Berhasil!',
        message: 'Data berhasil diupload ke Google Sheets.',
      ));
    } catch (e) {
      _sideEffectsController.add(ShowSnackbar(
        title: 'Gagal Upload',
        message: e.toString(),
        isError: true,
      ));
    } finally {
      _sheetApi.dispose();
      if (state is HomeFileLoaded) {
        emit((state as HomeFileLoaded).copyWith(isUploading: false));
      }
    }
  }

  void clearData() {
    _cleanup();
    emit(const HomeInitial());
  }

  void _cleanup() {
    final dir = _extractedDir;
    _extractedDir = null;
    dir?.delete(recursive: true).ignore();
  }

  @override
  Future<void> close() {
    _sideEffectsController.close();
    _cleanup();
    return super.close();
  }
}
