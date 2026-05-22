import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';
import 'package:json_converter/app/routes/app_pages.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../../data/core/utils/helpers.dart';

class HomeController extends GetxController {
  final _reader = FasihBackupReader();

  final selectedFile = Rxn<PlatformFile>();
  final isLoadingFile = false.obs;
  final isUploadingData = false.obs;
  final isExporting = false.obs;
  final appVersion = ''.obs;

  final discoveredTemplates = <FasihTemplate>[].obs;
  final selectedTemplate = Rxn<FasihTemplate>();
  final records = <FasihRecord>[].obs;

  Directory? _extractedDir;

  List<String> get columnHeaders =>
      selectedTemplate.value?.fields.map((f) => f.dataKey).toList() ?? [];

  @override
  void onInit() async {
    super.onInit();
    final info = await PackageInfo.fromPlatform();
    appVersion.value = 'v${info.version}';
  }

  @override
  void onClose() {
    _cleanup();
    super.onClose();
  }

  void goToSettings() => Get.toNamed(Routes.SETTINGS);

  Future<void> pickAndLoadBackup() async {
    if (Platform.isAndroid) {
      var status = await perm.Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await perm.Permission.manageExternalStorage.request();
        if (!status.isGranted) return;
      }
    }

    isLoadingFile.value = true;
    _cleanup();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      selectedFile.value = result.files.first;
      _extractedDir = await _reader.extractZip(File(path));
      final templates = await _reader.discoverTemplates(_extractedDir!);

      if (templates.isEmpty) {
        Get.snackbar(
          'Template Tidak Ditemukan',
          'Backup ini tidak memiliki template survey yang dapat diproses.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (templates.length == 1) {
        await _loadTemplate(templates.first);
      } else {
        discoveredTemplates.assignAll(templates);
        _showTemplatePicker(templates);
      }
    } catch (e) {
      Get.snackbar(
        'Kesalahan',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
    } finally {
      isLoadingFile.value = false;
    }
  }

  void _showTemplatePicker(List<FasihTemplate> templates) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Survey',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...templates.map(
              (t) => ListTile(
                title: Text(t.title),
                subtitle: Text('${t.fields.length} kolom · ${t.dataKey}'),
                onTap: () {
                  Get.back();
                  _loadTemplate(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTemplate(FasihTemplate template) async {
    isLoadingFile.value = true;
    try {
      selectedTemplate.value = template;
      final loaded = await _reader.loadRecords(_extractedDir!, template);
      records.assignAll(loaded);
    } finally {
      isLoadingFile.value = false;
    }
  }

  Future<void> exportToExcel() async {
    if (records.isEmpty || selectedTemplate.value == null) {
      Get.snackbar('Gagal', 'Data masih kosong.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isExporting.value = true;
    try {
      final template = selectedTemplate.value!;
      final headers = template.fields.map((f) => f.dataKey).toList();
      final labels = template.fields.map((f) => f.label).toList();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets.innerList.first;
      sheet.name = template.dataKey.length > 31
          ? template.dataKey.substring(0, 31)
          : template.dataKey;

      sheet.importList(labels, 1, 1, false);
      for (var i = 0; i < records.length; i++) {
        final row = headers.map((h) => records[i][h]).toList();
        sheet.importList(row, i + 2, 1, false);
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await createExportDir('Export');
      final fileName =
          '${p.basenameWithoutExtension(selectedFile.value!.name)}.xlsx';
      final file = File(p.join(dir, fileName));
      await file.writeAsBytes(bytes);

      Get.defaultDialog(
        title: 'Berhasil!',
        content: const Text('File Excel berhasil disimpan.'),
      );
    } catch (e) {
      Get.snackbar('Gagal Ekspor', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> shareExcel() async {
    final dir = await createExportDir('Export');
    final fileName =
        '${p.basenameWithoutExtension(selectedFile.value?.name ?? 'export')}.xlsx';
    final file = File(p.join(dir, fileName));
    if (!await file.exists()) {
      Get.snackbar('File Tidak Ada', 'Ekspor terlebih dahulu.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: fileName);
  }

  Future<void> uploadToSheets() async {
    if (records.isEmpty || selectedTemplate.value == null) {
      Get.snackbar('Gagal', 'Data masih kosong.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!SettingsRepository.instance.isConfigured) {
      Get.snackbar(
        'Belum Dikonfigurasi',
        'Buka Pengaturan dan isi credentials Google Sheets.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isUploadingData.value = true;
    try {
      final template = selectedTemplate.value!;
      final headers = template.fields.map((f) => f.dataKey).toList();
      final sheetTitle = template.dataKey.length > 100
          ? template.dataKey.substring(0, 100)
          : template.dataKey;

      await FasihConverterSheetApi.init(sheetTitle);

      final rows =
          records.map((r) => {for (final h in headers) h: r[h]}).toList();

      await FasihConverterSheetApi.appendRows(rows, headers);

      Get.defaultDialog(
        title: 'Berhasil!',
        backgroundColor: Colors.white,
        content: const Text('Data berhasil diupload ke Google Sheets.'),
      );
    } catch (e) {
      Get.defaultDialog(
        title: 'Gagal!',
        content: Text(e.toString()),
      );
    } finally {
      isUploadingData.value = false;
      FasihConverterSheetApi.dispose();
    }
  }

  void clearData() {
    _cleanup();
    selectedFile.value = null;
    selectedTemplate.value = null;
    records.clear();
    discoveredTemplates.clear();
  }

  void _cleanup() {
    final dir = _extractedDir;
    _extractedDir = null;
    dir?.delete(recursive: true).ignore();
  }
}
