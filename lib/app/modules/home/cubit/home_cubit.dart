import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_converter/app/data/models/backup_history_entry.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';
import 'package:json_converter/app/data/services/fasih_backup_writer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:share_plus/share_plus.dart';

import '../../../data/core/utils/helpers.dart';
import 'home_side_effect.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final FasihBackupReader _reader;
  final SettingsRepository _settings;
  final FasihConverterSheetApi _sheetApi;
  final FasihBackupWriter _writer;

  final _sideEffectsController = StreamController<HomeSideEffect>.broadcast();
  Stream<HomeSideEffect> get sideEffects => _sideEffectsController.stream;

  String appVersion = '';
  Directory? _extractedDir;
  Directory? get extractedDir => _extractedDir;

  List<FasihTemplate> _availableTemplates = [];
  List<FasihTemplate> get availableTemplates => _availableTemplates;

  HomeCubit(this._reader, this._settings, this._sheetApi, this._writer)
      : super(const HomeInitial()) {
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    appVersion = 'v${info.version}';
    await _tryRestoreLastSession();
  }

  Future<void> _tryRestoreLastSession() async {
    final dirPath = _settings.lastExtractedDirPath;
    final templateId = _settings.lastTemplateId;
    if (dirPath == null || templateId == null) return;

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await _settings.clearLastSession();
      return;
    }

    emit(const HomeLoadingFile());
    try {
      _extractedDir = dir;
      _availableTemplates = await _reader.discoverTemplates(dir);
      final template =
          _availableTemplates.where((t) => t.id == templateId).firstOrNull;
      if (template == null) {
        _extractedDir = null;
        await _settings.clearLastSession();
        emit(const HomeInitial());
        return;
      }
      final result = await _reader.loadRecords(dir, template);
      emit(HomeFileLoaded(
        file: PlatformFile(
          name: _settings.lastZipName ?? 'backup.zip',
          size: _settings.lastZipSize,
        ),
        template: template,
        records: result.records,
        respondentMeta: result.meta,
        envJson: result.envJson,
      ));
    } catch (_) {
      _extractedDir = null;
      _availableTemplates = [];
      await _settings.clearLastSession();
      emit(const HomeInitial());
    }
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
      final result = await FilePicker.pickFiles(
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
      _availableTemplates = await _reader.discoverTemplates(_extractedDir!);

      if (_availableTemplates.isEmpty) {
        _sideEffectsController.add(const ShowSnackbar(
          title: 'Template Tidak Ditemukan',
          message:
              'Backup ini tidak memiliki template survey yang dapat diproses.',
        ));
        emit(const HomeInitial());
        return;
      }

      if (_availableTemplates.length == 1) {
        await _loadTemplate(file, _availableTemplates.first);
      } else {
        emit(HomeMultiTemplate(file: file, templates: _availableTemplates));
        _sideEffectsController.add(ShowTemplatePicker(_availableTemplates));
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
    final file = switch (current) {
      HomeMultiTemplate(:final file) => file,
      HomeFileLoaded(:final file) => file,
      _ => null,
    };
    if (file == null) return;
    emit(const HomeLoadingFile());
    await _loadTemplate(file, template);
  }

  void changeTemplate() {
    if (_availableTemplates.length <= 1) return;
    _sideEffectsController.add(ShowTemplatePicker(_availableTemplates));
  }

  Future<void> _loadTemplate(PlatformFile file, FasihTemplate template) async {
    try {
      final result = await _reader.loadRecords(_extractedDir!, template);
      emit(HomeFileLoaded(
        file: file,
        template: template,
        records: result.records,
        respondentMeta: result.meta,
        envJson: result.envJson,
      ));
      await _settings.saveLastSession(
        extractedDirPath: _extractedDir!.path,
        templateId: template.id,
        zipName: file.name,
        zipSize: file.size,
      );
      await _settings.addToHistory(
        BackupHistoryEntry(
          dirPath: _extractedDir!.path,
          templateId: template.id,
          templateTitle: template.title,
          zipName: file.name,
          zipSize: file.size,
          loadedAt: DateTime.now(),
        ),
      );
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
      final workbook = _writer.buildWorkbook(
        template: current.template,
        records: current.records,
        respondentMeta: current.respondentMeta,
        envJson: current.envJson,
      );

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await createExportDir('Export');
      final fileName = '${_safeFileName(current.template.dataKey)}.xlsx';
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

  Future<void> importFromExcel() async {
    final current = state;
    if (current is! HomeFileLoaded) {
      _sideEffectsController.add(const ShowSnackbar(
        title: 'Gagal',
        message: 'Muat backup terlebih dahulu sebelum mengimpor Excel.',
      ));
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    emit(current.copyWith(isImporting: true));
    try {
      final workbook = _writer.buildWorkbook(
        template: current.template,
        records: current.records,
        respondentMeta: current.respondentMeta,
        envJson: current.envJson,
      );

      final outputName = '${_safeFileName(current.template.dataKey)}_edited';
      final outFile = await _writer.buildBackupZip(
        workbook: workbook,
        template: current.template,
        editedRecords: current.records,
        outputName: outputName,
      );
      workbook.dispose();

      _sideEffectsController.add(ShowImportSuccess(outFile.path));
    } catch (e) {
      _sideEffectsController.add(ShowSnackbar(
        title: 'Gagal Import',
        message: e.toString(),
        isError: true,
      ));
    } finally {
      if (state is HomeFileLoaded) {
        emit((state as HomeFileLoaded).copyWith(isImporting: false));
      }
    }
  }

  Future<void> shareExcel() async {
    final current = state;
    if (current is! HomeFileLoaded) return;

    final dir = await createExportDir('Export');
    final fileName = '${_safeFileName(current.template.dataKey)}.xlsx';
    final file = File(p.join(dir, fileName));
    if (!await file.exists()) {
      _sideEffectsController.add(const ShowSnackbar(
        title: 'File Tidak Ada',
        message: 'Ekspor terlebih dahulu.',
      ));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: fileName),
    );
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

  Future<void> loadFromHistory(BackupHistoryEntry entry) async {
    final dir = Directory(entry.dirPath);
    if (!await dir.exists()) {
      await _settings.removeFromHistory(entry.dirPath);
      _sideEffectsController.add(const ShowSnackbar(
        title: 'Sesi Tidak Ditemukan',
        message: 'Folder backup sudah tidak tersedia.',
        isError: true,
      ));
      return;
    }

    emit(const HomeLoadingFile());
    _cleanup();

    try {
      _extractedDir = dir;
      _availableTemplates = await _reader.discoverTemplates(dir);
      final template = _availableTemplates
          .where((t) => t.id == entry.templateId)
          .firstOrNull;
      if (template == null) {
        _extractedDir = null;
        _availableTemplates = [];
        _sideEffectsController.add(const ShowSnackbar(
          title: 'Template Tidak Ditemukan',
          message: 'Template survey tidak tersedia.',
          isError: true,
        ));
        emit(const HomeInitial());
        return;
      }
      await _loadTemplate(
        PlatformFile(name: entry.zipName, size: entry.zipSize),
        template,
      );
    } catch (e) {
      _extractedDir = null;
      _availableTemplates = [];
      emit(const HomeInitial());
      _sideEffectsController.add(ShowSnackbar(
        title: 'Kesalahan',
        message: e.toString(),
        isError: true,
      ));
    }
  }

  void clearData() {
    final dir = _extractedDir;
    _cleanup();
    dir?.delete(recursive: true).ignore();
    _settings.clearLastSession().ignore();
    emit(const HomeInitial());
  }

  void _cleanup() {
    _availableTemplates = [];
    _extractedDir = null;
    // Dirs are NOT deleted here — callers that want deletion do it explicitly.
  }

  /// Strips characters unsafe for filenames, collapses spaces to underscores.
  String _safeFileName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[^\w\-.]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  @override
  Future<void> close() {
    _sideEffectsController.close();
    _cleanup();
    return super.close();
  }
}
