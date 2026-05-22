import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

@RoutePage()
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Sheets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Obx(() => ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(
                    controller.credentialFileName.value ??
                        'Belum ada credentials',
                  ),
                  subtitle: const Text(
                    'Pilih file service account JSON dari Google Cloud Console',
                  ),
                  trailing: controller.credentialFileName.value != null
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: controller.clearCredentials,
                        )
                      : null,
                  onTap: controller.pickCredentialsFile,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                )),
            const SizedBox(height: 16),
            TextField(
              controller: controller.sheetIdController,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet ID atau URL',
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bagikan spreadsheet Anda dengan email service account '
              'agar aplikasi bisa menulis data.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton(
                  onPressed: controller.isSaving.value ? null : controller.save,
                  child: controller.isSaving.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
