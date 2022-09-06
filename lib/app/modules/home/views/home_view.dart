import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:get/get.dart';
import 'package:json_converter/app/data/core/utils/helpers.dart';
import 'package:json_converter/app/data/core/values/strings.dart';
import 'package:json_converter/app/data/models/art_data_source.dart';
import 'package:json_converter/app/data/models/art_fields.dart';
import 'package:json_converter/app/data/models/dd_fields.dart';
import 'package:json_converter/app/data/models/ruta_data_source.dart';
import 'package:json_converter/app/data/models/ruta_fields.dart';
import 'package:line_icons/line_icons.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as Excel;
import 'package:path/path.dart' show join;

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: Get.height * 0.1,
            ),
            Obx(
              () => Text(
                'Fasih Converter ${controller.appVersion.value}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              '© 2022 IPDS BPS Kabupaten Pinrang\nMade with ❤ by Fajrian Aidil Pratama',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(
              height: 32,
            ),
            DottedBorder(
              color: Colors.blueAccent,
              borderType: BorderType.RRect,
              dashPattern: const [8, 4],
              radius: const Radius.circular(12),
              child: Material(
                elevation: 0.0,
                color: const Color(0xFFDEDEDE).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: controller.readZip,
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    color: Colors.transparent,
                    child: AnimatedSwitcher(
                      duration: 500.milliseconds,
                      child: Obx(() => _buildCardBody()),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => OutlinedButton(
                      onPressed: () => controller.readXLSX(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                      ),
                      child: controller.isUploadingData.value
                          ? const SpinKitFadingCircle(
                              color: Colors.white,
                              size: 30,
                            )
                          : const Text('Bagikan File Export'),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                    child: Obx(
                  () => OutlinedButton(
                    onPressed: controller.selectedFile.value != null
                        ? () {
                            controller.selectedFile.value = null;
                            controller.rutaList.clear();
                            controller.artList.clear();
                            controller.ddList.clear();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.shade300,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    child: const Text('Hapus'),
                  ),
                )),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Obx(
              () => OutlinedButton.icon(
                label: controller.isExporting.value ? const Text('Mengekspor!') : const Text('Ekspor ke Excel'),
                onPressed: controller.isExporting.value
                    ? () {}
                    : () async {
                        controller.isExporting.value = true;
                        final artList = controller.artList;
                        final rutaList = controller.rutaList;
                        final ddList = controller.ddList;
                        final questions = [
                          'Nama KRT pada DSRT',
                          'Nama KRT pada C2 (R302 No urut 1)',
                          'Umur KRT (r306 No urut 1)',
                          'Jumlah ART sebagai Istri (Jumlah ART r303 = 3)',
                          'Umur anak tertua (R306 terbesar pada ART r303 = 4)',
                          'Jumlah ART (r112)',
                          'Jumlah ART Laki-Laki (Jumlah ART r304 = 1)',
                          'Jumlah ART Perempuan (Jumlah ART r304 = 2)',
                          'Jumlah ART >= 2 Tahun (Jumlah ART r306 >= 2)',
                          'Jumlah ART >= 5 Tahun (Jumlah ART r306 >= 5)',
                          'Jumlah Perempuan Usia 10 -54 (Jumlah ART r304 = 2 dan r306 = 10 - 54)',
                          'Jumlah Migrasi Internasional Sejak Juni 2017 (r501)',
                          'Jumlah Kematian 5 Tahun Terakhir (r602)',
                          'Jumlah Anak Lahir Hidup (Total r438 seluruh ART)',
                          'Jumlah Anak Lahir Hidup 5 Tahun Terakhir (Total r443a + r443b seluruh ART)',
                          'Jumlah Anak Lahir Hidup Setahun Terakhir (Total r445a + r445b seluruh ART)',
                          'Apakah terdapat ART 17 tahun kebawah dan berstatus kawin?',
                          'Apakah terdapat ART dengan status hubungan dengan KRT (r303) sebagai suami (02), istri (03), menantu (05), orang tua (07), atau mertua (08) dan umur < 10 tahun?',
                          'Apakah terdapat ART yang berusia 5 tahun kebawah (balita) yang memiliki gangguan pada Blok IV.412 - 420?',
                          'Apakah ada ART yang berbahasa daerah dengan tetangga (r424b = 1) namun tidak berbahasa daerah dalam keluarga (r424a = 2)?',
                          'Apakah ada ART yang bekerja sebagai supir angkutan antar daerah atau nelayan yang tempat bekerjanya berbeda kab/kota dengan tempat tinggal (r426 = 1) dan pulang rutin setiap hari (r427 = 1)?',
                          'Apakah jumlah anak yang dilahirkan hidup sejak Januari 2017 (r443a+r443b) lebih besar dari jumlah kehamilan (blok VII) pada masing-masing ART?',
                        ];

                        if (artList.isEmpty || rutaList.isEmpty) {
                          Get.defaultDialog(
                            title: 'Gagal!',
                            content: const Text('Data masih kosong!'),
                          );
                          return;
                        }

                        final Excel.Workbook workBook = Excel.Workbook();

                        final questionSheet =
                            workBook.worksheets.innerList.first;
                        final artSheet = workBook.worksheets.addWithName(
                            FlutterConfig.get(kEnvKeyArtSheetTitle));
                        final rutaSheet = workBook.worksheets.addWithName(
                            FlutterConfig.get(kEnvKeyRutaSheetTitle));
                        final ddlfSheet =
                            workBook.worksheets.addWithName('Pencacahan');

                        questionSheet
                            .importList(['No', 'Pertanyaan'], 1, 1, false);
                        questionSheet.importList(
                            List.generate(
                                questions.length, (index) => index + 1),
                            2,
                            1,
                            true);
                        questionSheet.importList(questions, 2, 2, true);

                        ddlfSheet.importList(
                            DDFields().getFields(), 1, 1, false);
                        for (var i = 1; i <= ddList.length; i++) {
                          final excelIndex = i + 1;
                          ddlfSheet.importList(
                            ddList[i - 1].values.toList(),
                            excelIndex,
                            1,
                            false,
                          );
                        }

                        artSheet.importList(
                            ARTFields().getFields(), 1, 1, false);
                        for (var i = 1; i <= artList.length; i++) {
                          artSheet.importList(
                            artList[i - 1].values.toList(),
                            i + 1,
                            1,
                            false,
                          );
                        }

                        rutaSheet.importList(
                            RutaFields().getFields(), 1, 1, false);
                        for (var i = 1; i <= rutaList.length; i++) {
                          rutaSheet.importList(
                            rutaList[i - 1].values.toList(),
                            i + 1,
                            1,
                            false,
                          );
                        }

                        var fileBytes = workBook.saveAsStream();

                        var directory = await createFolderInAppDocDir('Export');
                        var fileName = controller.selectedFile.value?.name
                            .replaceAll('.zip', '.xlsx');
                        File(join('$directory/$fileName'))
                            .writeAsBytes(fileBytes);
                        workBook.dispose();

                        controller.isExporting.value = false;
                        Get.defaultDialog(
                          title: 'Berhasil!',
                          content: const Text('Berhasil menyimpan file!'),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.green.shade300,
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                ),
                icon: controller.isExporting.value
                    ? const SpinKitFadingCircle(
                        color: Colors.white,
                        size: 30,
                      )
                    : const Icon(
                        LineIcons.excelFile,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(
              height: 32,
            ),
            SizedBox(
              width: Get.width,
              height: Get.height * 0.5,
              child: Obx(
                () => DefaultTabController(
                  length: 2,
                  child: Container(
                    width: Get.width,
                    height: Get.height * 0.5,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.2),
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                            blurRadius: 10,
                          )
                        ]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TabBar(
                          indicatorColor: Colors.blueAccent,
                          labelColor: Colors.blueAccent,
                          unselectedLabelColor: Colors.blueGrey,
                          tabs: [
                            Tab(
                              child: Text('Tabel RUTA'),
                            ),
                            Tab(
                              child: Text('Tabel ART'),
                            )
                          ],
                        ),
                        SizedBox(
                          height: Get.height * 0.4,
                          child: TabBarView(
                            children: [
                              _buildRutaList(),
                              _buildArtList(),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBody() {
    if (controller.selectedFile.value == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.upload_file,
            color: Colors.blueAccent,
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            'Upload File Backup Fasih (.zip)',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
            ),
          )
        ],
      );
    }

    if (controller.isLoadingFile.value) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 30,
        ),
      );
    }

    final file = controller.selectedFile.value!;
    final fileSize = filesize(file.size);

    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: Icon(
              Icons.file_present,
              color: Colors.blueAccent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(
                  height: 8,
                ),
                Text('Ukuran : $fileSize'),
                Text('Jumlah Ruta : ${controller.rutaList.length} ruta'),
                Text('Jumlah ART  : ${controller.artList.length} art'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRutaList() {
    return SizedBox(
      height: Get.height * 0.4,
      width: Get.width,
      child: PaginatedDataTable2(
        source: RutaDataSource(
          data: controller.rutaList,
          selectedRowCount: 10,
        ),
        empty: controller.isLoadingFile.value
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SpinKitFadingCircle(
                    color: Colors.black,
                    size: 30,
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text('Memuat data Ruta!')
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.file_open_rounded),
                  SizedBox(
                    height: 4,
                  ),
                  Text('Belum ada data RUTA!')
                ],
              ),
        border: TableBorder.all(
          color: Colors.grey,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        ),
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade100),
        minWidth: Get.width * 12,
        columns: RutaFields()
            .getFields()
            .map(
              (e) => DataColumn2(
                label: Text(e),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildArtList() {
    return SizedBox(
      height: Get.height * 0.4,
      width: Get.width,
      child: PaginatedDataTable2(
        availableRowsPerPage: const [10, 15, 20],
        wrapInCard: true,
        fit: FlexFit.tight,
        columnSpacing: 30,
        empty: controller.isLoadingFile.value
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SpinKitFadingCircle(
                    color: Colors.black,
                    size: 30,
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text('Memuat data ART!')
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.file_open_rounded),
                  SizedBox(
                    height: 4,
                  ),
                  Text('Belum ada data ART!')
                ],
              ),
        source: ARTDataSource(
          data: controller.artList,
        ),
        border: TableBorder.all(
          color: Colors.grey,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        ),
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade100),
        minWidth: Get.width * 30,
        columns: ARTFields()
            .getFields()
            .map(
              (e) => DataColumn2(
                label: Text(e),
              ),
            )
            .toList(),
      ),
    );
  }
}
