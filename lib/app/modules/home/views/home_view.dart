import 'package:auto_route/auto_route.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:line_icons/line_icons.dart';

import '../controllers/home_controller.dart';

@RoutePage()
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: controller.goToSettings,
            tooltip: 'Pengaturan',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => Text(
                'Fasih Converter ${controller.appVersion.value}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '© 2022 IPDS BPS Kabupaten Pinrang',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
            const SizedBox(height: 24),
            _buildDropZone(),
            const SizedBox(height: 16),
            _buildActionRow(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return DottedBorder(
      color: Colors.blueAccent,
      borderType: BorderType.RRect,
      dashPattern: const [8, 4],
      radius: const Radius.circular(12),
      child: Material(
        elevation: 0,
        color: const Color(0xFFDEDEDE).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: controller.pickAndLoadBackup,
          child: SizedBox(
            width: double.infinity,
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Obx(() => _buildDropZoneContent()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZoneContent() {
    if (controller.isLoadingFile.value) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 30),
      );
    }

    final file = controller.selectedFile.value;
    if (file == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file, color: Colors.blueAccent),
          SizedBox(height: 8),
          Text(
            'Upload File Backup Fasih (.zip)',
            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
        ],
      );
    }

    return Row(
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: Icon(Icons.file_present, color: Colors.blueAccent),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                file.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('Ukuran: ${filesize(file.size)}'),
              Obx(
                () => Text(
                  controller.selectedTemplate.value != null
                      ? '${controller.selectedTemplate.value!.title} · '
                          '${controller.records.length} responden'
                      : 'Memilih template...',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Obx(() {
      final hasData = controller.records.isNotEmpty;
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasData ? controller.shareExcel : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Bagikan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: hasData ? controller.clearData : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red.shade300,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  child: const Text('Hapus'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasData && !controller.isExporting.value
                      ? controller.exportToExcel
                      : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: controller.isExporting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LineIcons.excelFile, size: 18),
                  label: const Text('Ekspor Excel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasData && !controller.isUploadingData.value
                      ? controller.uploadToSheets
                      : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.teal.shade400,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: controller.isUploadingData.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Upload Sheets'),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildDataTable() {
    return Obx(() {
      final template = controller.selectedTemplate.value;
      final records = controller.records;

      if (template == null) {
        return const SizedBox.shrink();
      }

      final columns = template.fields
          .map((f) => DataColumn2(label: Text(f.label), fixedWidth: 150))
          .toList();

      return Container(
        height: Get.height * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withValues(alpha: 0.2),
              spreadRadius: 4,
              offset: const Offset(0, 8),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: DataTable2(
          columnSpacing: 12,
          minWidth: template.fields.length * 150.0,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade100),
          border: TableBorder.all(color: Colors.grey.shade300),
          empty: records.isEmpty
              ? const Center(child: Text('Belum ada data'))
              : null,
          columns: columns,
          rows: records
              .take(200)
              .map(
                (record) => DataRow2(
                  cells: template.fields
                      .map(
                        (f) => DataCell(
                          Text(
                            record[f.dataKey],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      );
    });
  }
}
