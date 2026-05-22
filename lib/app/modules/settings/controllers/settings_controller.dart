import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';

class SettingsController extends GetxController {
  final sheetIdController = TextEditingController();
  final credentialFileName = RxnString();
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final repo = SettingsRepository.instance;
    if (repo.sheetId != null) {
      sheetIdController.text = repo.sheetId!;
    }
    if (repo.credentialsJson != null) {
      credentialFileName.value = 'Credentials tersimpan';
    }
  }

  @override
  void onClose() {
    sheetIdController.dispose();
    super.onClose();
  }

  Future<void> pickCredentialsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final content = await file.readAsString();
    final repo = SettingsRepository.instance;

    if (!repo.validateCredentialJson(content)) {
      Get.snackbar(
        'Format Tidak Valid',
        'File bukan service account JSON yang valid.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
      return;
    }

    await repo.saveCredentials(content);
    credentialFileName.value = result.files.first.name;
  }

  Future<void> save() async {
    final rawInput = sheetIdController.text.trim();
    if (rawInput.isEmpty) {
      Get.snackbar(
        'Input Kosong',
        'Masukkan Spreadsheet ID atau URL.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final id = SettingsRepository.extractSheetId(rawInput) ?? rawInput;
    isSaving.value = true;
    await SettingsRepository.instance.saveSheetId(id);
    isSaving.value = false;

    Get.snackbar(
      'Tersimpan',
      'Pengaturan berhasil disimpan.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade400,
      colorText: Colors.white,
    );
  }

  Future<void> clearCredentials() async {
    await SettingsRepository.instance.clearCredentials();
    credentialFileName.value = null;
  }
}
