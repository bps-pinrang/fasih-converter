import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';

import 'settings_side_effect.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _settings;

  final _sideEffectsController =
      StreamController<SettingsSideEffect>.broadcast();
  Stream<SettingsSideEffect> get sideEffects => _sideEffectsController.stream;

  String? _credentialsJson;

  SettingsCubit(this._settings)
      : super(SettingsInitial(
          sheetId: _settings.sheetId ?? '',
          hasCredentials: _settings.credentialsJson != null,
        ));

  Future<void> pickCredentialsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final json = await File(path).readAsString();
    if (!_settings.validateCredentialJson(json)) {
      _sideEffectsController.add(const ShowSettingsSnackbar(
        title: 'File Tidak Valid',
        message: 'File JSON tidak mengandung kredensial Google yang valid.',
        isError: true,
      ));
      return;
    }
    _credentialsJson = json;
    _sideEffectsController.add(const ShowSettingsSnackbar(
      title: 'File Dipilih',
      message: 'Kredensial berhasil dimuat.',
    ));
  }

  Future<void> save(String sheetIdInput) async {
    final sheetId =
        SettingsRepository.extractSheetId(sheetIdInput) ?? sheetIdInput.trim();

    if (sheetId.isEmpty) {
      _sideEffectsController.add(const ShowSettingsSnackbar(
        title: 'Gagal',
        message: 'Sheet ID tidak boleh kosong.',
        isError: true,
      ));
      return;
    }

    emit(const SettingsSaving());
    try {
      if (_credentialsJson != null) {
        await _settings.saveCredentials(_credentialsJson!);
      }
      await _settings.saveSheetId(sheetId);
      emit(const SettingsSaved());
      _sideEffectsController.add(const ShowSettingsSnackbar(
        title: 'Tersimpan',
        message: 'Pengaturan berhasil disimpan.',
      ));
    } catch (e) {
      emit(SettingsInitial(
        sheetId: sheetId,
        hasCredentials: _settings.credentialsJson != null,
      ));
      _sideEffectsController.add(ShowSettingsSnackbar(
        title: 'Gagal',
        message: e.toString(),
        isError: true,
      ));
    }
  }

  Future<void> clearCredentials() async {
    await _settings.clearAll();
    _credentialsJson = null;
    emit(const SettingsInitial());
    _sideEffectsController.add(const ShowSettingsSnackbar(
      title: 'Dihapus',
      message: 'Semua kredensial telah dihapus.',
    ));
  }

  @override
  Future<void> close() {
    _sideEffectsController.close();
    return super.close();
  }
}
