import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_converter/app/data/models/backup_history_entry.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';
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
import '../../../data/models/respondent_load_result.dart';
import '../../../data/services/app_error_logger.dart';
import 'home_side_effect.dart';
import 'home_state.dart';

// ---------------------------------------------------------------------------
// Isolate helpers for loadRecords — must be top-level so Isolate.spawn can
// send them across isolate boundaries.
// ---------------------------------------------------------------------------

class _LoadArgs {
  final String dirPath;
  final FasihTemplate template;
  final SendPort sendPort;
  final Map<String, String> wrappedDataKeys;

  const _LoadArgs(
    this.dirPath,
    this.template,
    this.sendPort, {
    this.wrappedDataKeys = const {},
  });
}

class _LoadProgress {
  final int loaded;
  final int total;
  const _LoadProgress(this.loaded, this.total);
}

class _LoadRecord {
  final FasihRecord record;
  final RespondentMeta meta;
  const _LoadRecord(this.record, this.meta);
}

class _LoadDone {
  final String envJson;
  const _LoadDone(this.envJson);
}

class _LoadError {
  final String message;
  final String stackTrace;
  const _LoadError(this.message, this.stackTrace);
}

void _loadRecordsEntry(_LoadArgs args) async {
  try {
    final result = await FasihBackupReader().loadRecords(
      Directory(args.dirPath),
      args.template,
      wrappedDataKeys: args.wrappedDataKeys,
      onProgress: (loaded, total) =>
          args.sendPort.send(_LoadProgress(loaded, total)),
      onRecord: (record, meta) => args.sendPort.send(_LoadRecord(record, meta)),
    );
    args.sendPort.send(_LoadDone(result.envJson));
  } catch (e, st) {
    args.sendPort.send(_LoadError(e.toString(), st.toString()));
  }
}

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

  Isolate? _loadIsolate;
  ReceivePort? _loadPort;
  Timer? _stallTimer;

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
      final result = await _loadRecordsWithProgress(dirPath, template);
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
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'restoreLastSession',
          if (_settings.lastZipName != null)
            'nama_backup': _settings.lastZipName!,
          if (_settings.lastTemplateId != null)
            'id_template': _settings.lastTemplateId!,
        },
      );
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
      _extractedDir = await _reader.extractZip(
        File(path),
        onProgress: (current, total) {
          if (!isClosed) {
            emit(HomeLoadingFile(
              loaded: current,
              total: total,
              subtitle: 'Mengekstrak berkas ($current / $total)...',
            ));
          }
        },
      );
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
    } catch (e, st) {
      AppErrorLogger.instance
          .log(e, st, context: {'operasi': 'pickAndLoadBackup'});
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
      final result =
          await _loadRecordsWithProgress(_extractedDir!.path, template);
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
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'loadTemplate',
          'nama_backup': file.name,
          'ukuran_backup': '${file.size} bytes',
          'nama_template': template.title,
          'id_template': template.id,
          'jumlah_kolom': '${template.fields.length}',
        },
      );
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
      final records = current.records;
      final respondentMeta = current.respondentMeta;
      final envJson = current.envJson;

      final bytes = await Isolate.run(() => FasihBackupWriter().buildBytes(
            template: template,
            records: records,
            respondentMeta: respondentMeta,
            envJson: envJson,
          ));

      final dir = await createExportDir('Export');
      final fileName = '${_safeFileName(current.template.dataKey)}.xlsx';
      final file = File(p.join(dir, fileName));
      await file.writeAsBytes(bytes);

      _sideEffectsController.add(const ShowSuccessDialog(
        title: 'Berhasil!',
        message: 'File Excel berhasil disimpan.',
      ));
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'exportToExcel',
          'nama_backup': current.file.name,
          'nama_template': current.template.title,
          'id_template': current.template.id,
          'jumlah_responden': '${current.records.length}',
          'jumlah_kolom': '${current.template.fields.length}',
        },
      );
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
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'importFromExcel',
          'nama_backup': current.file.name,
          'nama_template': current.template.title,
          'id_template': current.template.id,
          'jumlah_responden': '${current.records.length}',
          'jumlah_kolom': '${current.template.fields.length}',
        },
      );
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
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'uploadToSheets',
          'nama_backup': current.file.name,
          'nama_template': current.template.title,
          'id_template': current.template.id,
          'jumlah_responden': '${current.records.length}',
          'jumlah_kolom': '${current.template.fields.length}',
        },
      );
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
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'loadFromHistory',
          'nama_backup': entry.zipName,
          'id_template': entry.templateId,
          'nama_template': entry.templateTitle,
        },
      );
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

  /// Re-runs record loading with server-supplied GCM keys, unlocking
  /// previously encrypted data.json files in the current backup.
  Future<void> reloadWithKeyMap(Map<String, String> keyMap) async {
    final current = state;
    if (current is! HomeFileLoaded || _extractedDir == null) return;
    emit(const HomeLoadingFile(subtitle: 'Mendekripsi data dari server...'));
    try {
      final result = await _loadRecordsWithProgress(
        _extractedDir!.path,
        current.template,
        wrappedDataKeys: keyMap,
      );
      emit(current.copyWith(
        records: result.records,
        respondentMeta: result.meta,
      ));
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {'operasi': 'reloadWithKeyMap'},
      );
      emit(current); // restore previous state on failure
      _sideEffectsController.add(ShowSnackbar(
        title: 'Gagal Dekripsi',
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

  /// Spawns a background isolate to run [loadRecords], streaming progress
  /// updates back to the main thread via [ReceivePort].
  Future<RespondentLoadResult> _loadRecordsWithProgress(
    String dirPath,
    FasihTemplate template, {
    Map<String, String> wrappedDataKeys = const {},
  }) async {
    _loadPort?.close();
    _loadIsolate?.kill(priority: Isolate.immediate);

    final completer = Completer<RespondentLoadResult>();
    final port = ReceivePort();
    _loadPort = port;

    _loadIsolate = await Isolate.spawn(
      _loadRecordsEntry,
      _LoadArgs(dirPath, template, port.sendPort,
          wrappedDataKeys: wrappedDataKeys),
    );

    final records = <FasihRecord>[];
    final metas = <RespondentMeta>[];

    port.listen((msg) {
      if (msg is _LoadProgress) {
        _stallTimer?.cancel();
        if (!isClosed) {
          emit(HomeLoadingFile(loaded: msg.loaded, total: msg.total));
        }
        // If no progress update for 500 ms the isolate is still finalising
        // (e.g. building envJson). Show a subtitle so the user knows the app
        // isn't frozen.
        _stallTimer = Timer(const Duration(milliseconds: 500), () {
          if (isClosed) return;
          final s = state;
          if (s is HomeLoadingFile && s.subtitle == null) {
            emit(HomeLoadingFile(
              loaded: s.loaded,
              total: s.total,
              subtitle: 'Menyiapkan data, harap tunggu...',
            ));
          }
        });
      } else if (msg is _LoadRecord) {
        records.add(msg.record);
        metas.add(msg.meta);
      } else if (msg is _LoadDone) {
        _stallTimer?.cancel();
        port.close();
        _loadPort = null;
        _loadIsolate = null;
        if (!completer.isCompleted) {
          completer.complete(RespondentLoadResult(
            records: records,
            meta: metas,
            envJson: msg.envJson,
          ));
        }
      } else if (msg is _LoadError) {
        _stallTimer?.cancel();
        port.close();
        _loadPort = null;
        _loadIsolate = null;
        AppErrorLogger.instance.log(
          msg.message,
          StackTrace.fromString(msg.stackTrace),
          context: {
            'operasi': 'loadRecords',
            'template_nama': template.title,
            'id_template': template.id,
            'jumlah_kolom': '${template.fields.length}',
          },
        );
        if (!completer.isCompleted) completer.completeError(msg.message);
      }
    });

    return completer.future;
  }

  /// Strips characters unsafe for filenames, collapses spaces to underscores.
  String _safeFileName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[^\w\-.]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  @override
  Future<void> close() {
    _stallTimer?.cancel();
    _loadPort?.close();
    _loadIsolate?.kill(priority: Isolate.immediate);
    _sideEffectsController.close();
    _cleanup();
    return super.close();
  }
}
