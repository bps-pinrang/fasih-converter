import 'dart:convert';
import 'dart:io';

import 'package:async_zip/async_zip.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:get/get.dart';
import 'package:gsheets/gsheets.dart';
import 'package:json_converter/app/data/core/utils/helpers.dart';
import 'package:json_converter/app/data/core/values/strings.dart';
import 'package:json_converter/app/data/models/art_fields.dart';
import 'package:json_converter/app/data/models/dd_fields.dart';
import 'package:json_converter/app/data/models/ruta_fields.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:share_plus/share_plus.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final zipReader = ZipFileReader();

  final Rxn<PlatformFile> selectedFile = Rxn(null);
  final isLoadingFile = false.obs;
  final isUploadingData = false.obs;
  final rutaList = List<Map<String, dynamic>>.empty(growable: true).obs;
  final artList = List<Map<String, dynamic>>.empty(growable: true).obs;
  final ddList = List<Map<String, dynamic>>.empty(growable: true).obs;
  final isExporting = false.obs;

  final appVersion = ''.obs;

  @override
  void onInit() async {
    super.onInit();
    var packageInfo = await PackageInfo.fromPlatform();
    appVersion.value = 'v${packageInfo.version}';
  }

  Future readXLSX(BuildContext context) async {
    try {
      perm.PermissionStatus status = await perm.Permission.storage.status;

      do {
        status = await perm.Permission.storage.request();
      } while (status != perm.PermissionStatus.granted);

      final path = await createFolderInAppDocDir('Export');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        initialDirectory: path,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final box = context.findRenderObject() as RenderBox?;
        Share.shareFiles(
          [result.files.first.path!],
          text: result.files.first.name,
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      //
    }
  }

  Future readZip() async {
    try {
      perm.PermissionStatus status = await perm.Permission.storage.status;

      do {
        status = await perm.Permission.storage.request();
      } while (status != perm.PermissionStatus.granted);

      isLoadingFile.value = true;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['zip']);

      if (result != null) {
        rutaList.clear();
        artList.clear();
        ddList.clear();
        selectedFile.value = result.files.first;
        zipReader.open(File(selectedFile.value!.path!));
        final entries = zipReader.entries();
        Directory appDir = await getApplicationDocumentsDirectory();
        final dirName = selectedFile.value!.name.replaceAll('.zip', '');
        final destinationDir =
            await Directory('${appDir.path}/$dirName').create(recursive: true);
        await ZipFile.extractToDirectory(
          zipFile: File(selectedFile.value!.path!),
          destinationDir: destinationDir,
        );

        var excelIndex = 2;
        for (final entry in entries) {
          if (entry.name.contains('data.json')) {
            var dir = destinationDir.path + entry.name;
            final jsonData = File(dir);
            var json = jsonDecode(jsonData.readAsStringSync());

            final artCount = int.parse(json[kColumnAnswers]
                    .firstWhere(
                      (el) => el[kColumnDataKey] == RutaFields().artTotal,
                      orElse: () => null,
                    )?[kColumnAnswer]
                    .toString() ??
                '0');

            final rutaData = {
              RutaFields().province: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().province,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().regency: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().regency,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().district: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().district,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().village: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().village,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().classification: json[kColumnAnswers]
                      .firstWhere(
                        (el) =>
                            el[kColumnDataKey] == RutaFields().classification,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().nks: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().nks,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().nobs: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().nobs,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().nobang: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().nobang,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().nus: json[kColumnAnswers].firstWhere(
                    (el) => el[kColumnDataKey] == RutaFields().nus,
                    orElse: () => null,
                  )?[kColumnAnswer]?[0]?[kColumnValue] ??
                  '',
              RutaFields().address: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().address,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().krtName: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().krtName,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().r111Val: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r111Val,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().artTotal: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().artTotal,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().contactName: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().contactName,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().contactPhone: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().contactPhone,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().contactEmail: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().contactEmail,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().r114: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r114,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r501: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r501,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r601: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r601,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r602: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r602,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '0',
              RutaFields().r701: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r701,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r801: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r801,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r802: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r802,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r803: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r803,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r804: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r804,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().r805: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r805,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r806: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r806,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r807: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r807,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r808: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r808,
                        orElse: () => null,
                      )?[kColumnAnswer]?[0]?[kColumnValue]
                      .toString() ??
                  '',
              RutaFields().r809a: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r809a,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              RutaFields().r809b: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == RutaFields().r809b,
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
            };

            final List<Map<String, dynamic>> localART =
                List.empty(growable: true);

            for (var i = 1; i <= artCount; i++) {
              final artData = {
                ARTFields().province: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().province,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().regency: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().regency,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().district: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().district,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().village: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().village,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().classification: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == ARTFields().classification,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().nks: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().nks,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().nobs: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().nobs,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().nobang: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().nobang,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().nus: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().nus,
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().address: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().address,
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().krtName: json[kColumnAnswers]
                        .firstWhere(
                          (el) => el[kColumnDataKey] == ARTFields().krtName,
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r301: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r301}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r302Name: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] ==
                              '${ARTFields().r302Name}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r303: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r303}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r304: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r304}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r305a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r305a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r305b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r305b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r305c: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r305c}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r306: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r306}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r307: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r307}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r308: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r308}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r308a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r308a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r400: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r400}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r401: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r401}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r402a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r402a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r403Val: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r403Val}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r404: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r404}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r405: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r405}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r406a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r406a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r406b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r406b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r406c: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r406c}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r406e: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r406e}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r407: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r407}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r408a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r408a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r408b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r408b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r408c: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r408c}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnLabel]
                        .toString() ??
                    '',
                ARTFields().r412: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r412}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r413: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r413}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r414: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r414}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r415: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r415}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r416: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r416}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r417: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r417}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r418: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r418}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r419: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r419}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r420: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r420}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r421: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r421}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r422: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r422}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r423: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r423}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r424a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r424a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r424aLanguage: json[kColumnAnswers].firstWhere(
                      (el) =>
                          el[kColumnDataKey] ==
                          '${ARTFields().r424aLanguage}#$i',
                      orElse: () => null,
                    )?[kColumnAnswer]?[0]?[kColumnLabel] ??
                    '',
                ARTFields().r424b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r424b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r424bLanguage: json[kColumnAnswers].firstWhere(
                      (el) =>
                          el[kColumnDataKey] ==
                          '${ARTFields().r424bLanguage}#$i',
                      orElse: () => null,
                    )?[kColumnAnswer]?[0]?[kColumnLabel] ??
                    '',
                ARTFields().r425: json[kColumnAnswers].firstWhere(
                      (el) => el[kColumnDataKey] == '${ARTFields().r425}#$i',
                      orElse: () => null,
                    )?[kColumnAnswer]?[0]?[kColumnLabel] ??
                    '',
                ARTFields().r426: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r426}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r427: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r427}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r428: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r428}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r429: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r429}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r430: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r430}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r431: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r431}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r432: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r432}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r433: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r433}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r434: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r434}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r434Code: json[kColumnAnswers].firstWhere(
                      (el) =>
                          el[kColumnDataKey] == '${ARTFields().r434Code}#$i',
                      orElse: () => null,
                    )?[kColumnAnswer]?[0]?[kColumnLabel] ??
                    '',
                ARTFields().r435: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r435}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r435Code: json[kColumnAnswers].firstWhere(
                      (el) =>
                          el[kColumnDataKey] == '${ARTFields().r435Code}#$i',
                      orElse: () => null,
                    )?[kColumnAnswer]?[0]?[kColumnLabel] ??
                    '',
                ARTFields().r436: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r436}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r437Val: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r437Val}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r438: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r438}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r439a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r439a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r439b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r439b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r440a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r440a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r440b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r440b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r441a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r441a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r441b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r441b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r442: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r442}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r443a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r443a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r443b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r443b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r444: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r444}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]?[0]?[kColumnValue]
                        .toString() ??
                    '',
                ARTFields().r445a: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r445a}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
                ARTFields().r445b: json[kColumnAnswers]
                        .firstWhere(
                          (el) =>
                              el[kColumnDataKey] == '${ARTFields().r445b}#$i',
                          orElse: () => null,
                        )?[kColumnAnswer]
                        .toString() ??
                    '',
              };
              artList.add(artData);
              localART.add(artData);
            }

            final children = localART
                .where((element) => element[ARTFields().r303].contains('4'))
                .toList();
            final ddData = {
              DDFields().regionID:
                  rutaData[RutaFields().village] + rutaData[RutaFields().nobs],
              DDFields().supervisor: '',
              DDFields().krt: rutaData[RutaFields().krtName],
              DDFields().buildingNumb:
                  rutaData[RutaFields().nobang].toString().padLeft(3, '0'),
              DDFields().queueNumb: rutaData[RutaFields().nus],
              DDFields().pcl: '0',
              DDFields().question1: rutaData[RutaFields().krtName],
              DDFields().question2: json[kColumnAnswers]
                      .firstWhere(
                        (el) =>
                            el[kColumnDataKey] == '${ARTFields().r302Name}#1',
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              DDFields().question3: json[kColumnAnswers]
                      .firstWhere(
                        (el) => el[kColumnDataKey] == '${ARTFields().r306}#1',
                        orElse: () => null,
                      )?[kColumnAnswer]
                      .toString() ??
                  '',
              DDFields().question4: localART
                  .where((art) => art[ARTFields().r303].contains('3'))
                  .length,
              DDFields().question5: children.isEmpty
                  ? 0
                  : children.reduce((a, b) => int.parse(a[ARTFields().r306]) >
                          int.parse(b[ARTFields().r306])
                      ? a
                      : b)[ARTFields().r306],
              DDFields().question6: artCount,
              DDFields().question7: localART
                  .where((art) => art[ARTFields().r304].contains('1'))
                  .length,
              DDFields().question8: localART
                  .where((art) => art[ARTFields().r304].contains('2'))
                  .length,
              DDFields().question9: localART
                  .where((art) =>
                      int.parse(art[ARTFields().r306].isEmpty
                          ? '0'
                          : art[ARTFields().r306]) >=
                      2)
                  .length,
              DDFields().question10: localART
                  .where((art) =>
                      int.parse(art[ARTFields().r306].isEmpty
                          ? '0'
                          : art[ARTFields().r306]) >=
                      5)
                  .length,
              DDFields().question11: localART
                  .where((art) =>
                      art[ARTFields().r304].contains('2') &&
                      (int.parse(art[ARTFields().r306].isEmpty
                                  ? '0'
                                  : art[ARTFields().r306]) >=
                              10 &&
                          int.parse(art[ARTFields().r306].isEmpty
                                  ? '0'
                                  : art[ARTFields().r306]) <=
                              54))
                  .length,
              DDFields().question12: rutaData[RutaFields().r501],
              DDFields().question13: rutaData[RutaFields().r602],
              DDFields().question14: localART.fold(0, (num sum, art) {
                var r438 = 0;

                if (art[ARTFields().r438] != null) {
                  r438 = art[ARTFields().r438].isEmpty
                      ? 0
                      : int.parse(art[ARTFields().r438]);
                }

                return sum + r438;
              }),
              DDFields().question15: localART.fold(0, (num sum, art) {
                var a443 = 0;

                if (art[ARTFields().r443a] != null) {
                  a443 = art[ARTFields().r443a].isEmpty
                      ? 0
                      : int.parse(art[ARTFields().r443a]);
                }

                var b443 = 0;

                if (art[ARTFields().r443b] != null) {
                  b443 = art[ARTFields().r443b].isEmpty
                      ? 0
                      : int.parse(art[ARTFields().r443b]);
                }

                return sum + (a443 + b443);
              }),
              DDFields().question16: localART.fold(0, (num sum, art) {
                var a445 = 0;

                if (art[ARTFields().r445a] != null) {
                  a445 = art[ARTFields().r445a].isEmpty
                      ? 0
                      : int.parse(art[ARTFields().r445a]);
                }

                var b445 = 0;

                if (art[ARTFields().r445b] != null) {
                  b445 = art[ARTFields().r445b].isEmpty
                      ? 0
                      : int.parse(art[ARTFields().r445b]);
                }

                return sum + (a445 + b445);
              }),
              DDFields().question17: localART.where((element) {
                var age = 0;
                if (element[ARTFields().r306] != '') {
                  age = int.parse(element[ARTFields().r306]);
                }
                return element[ARTFields().r307].contains('2') && age <= 17;
              }).isNotEmpty
                  ? '1'
                  : '0',
              DDFields().question18: localART.where((element) {
                var status = '00';
                var age = 0;

                if (element[ARTFields().r306] != '') {
                  age = int.parse(element[ARTFields().r306]);
                }

                if (element[ARTFields().r303] != '') {
                  status = element[ARTFields().r303].toString().padLeft(2, '0');
                }

                return ['02', '03', '05', '07', '08'].contains(status) &&
                    age < 10;
              }).isNotEmpty
                  ? '1'
                  : '0',
              DDFields().question19: localART.where((element) {
                var age = 0;

                if (element[ARTFields().r306] != '') {
                  age = int.parse(element[ARTFields().r306]);
                }

                var disease = 0;
                for (var i = 412; i <= 420; i++) {
                  if (!element['r$i'].contains('4')) {
                    disease++;
                  }
                }

                return disease > 0 && age <= 5;
              }).isNotEmpty
                  ? '1'
                  : '0',
              DDFields().question20: localART
                      .where((element) =>
                          element[ARTFields().r424b].contains('1') &&
                          element[ARTFields().r424a].contains('2'))
                      .isNotEmpty
                  ? '1'
                  : '0',
              DDFields().question21: '0',
              DDFields().question22: '0',
              DDFields().rule1: '0',
              DDFields().rule2: '0',
              DDFields().rule3: '0',
              DDFields().rule4: '0',
              DDFields().rule5: '0',
              DDFields().rule6: '0',
              DDFields().rule7: '0',
              DDFields().rule8: '0',
              DDFields().rule9: '0',
              DDFields().rule10: '0',
              DDFields().status:
                  '=IF(AC$excelIndex="";"";IF(COUNTIF(AC$excelIndex:AL$excelIndex;1)=10;"CLEAN";IF(COUNTIF(AC$excelIndex:AL$excelIndex;2)>0;"WARNING CLEAN";IF(COUNTIF(AC$excelIndex:AL$excelIndex;3)>0;"WARNING";"BELUM"))))',
              DDFields().notes: '',
              DDFields().unique: rutaData[RutaFields().village] +
                  rutaData[RutaFields().nobs] +
                  rutaData[RutaFields().nus],
              DDFields().kab: rutaData[RutaFields().regency],
            };

            ddList.add(ddData);
            rutaList.add(rutaData);
            excelIndex++;
          }
        }
        destinationDir.delete(recursive: true);
      }
    } on ZipException catch (e) {
      debugPrint(e.toString());
    } catch (e) {
      debugPrint('Kesalahan : ${e.toString()}');
    } finally {
      zipReader.close();
      isLoadingFile.value = false;
    }
  }

  Future uploadData() async {
    try {
      isUploadingData.value = true;
      await FasihConverterSheetApi.insertART(artList);
      await FasihConverterSheetApi.insertRuta(rutaList);
      await Future.delayed(
        1.seconds,
        () {
          Get.defaultDialog(
            title: 'Berhasil!',
            backgroundColor: Colors.white,
            content: const Text('Berhasil upload data!'),
          );

          selectedFile.value = null;
          rutaList.clear();
          artList.clear();
          ddList.clear();
        },
      );
    } on GSheetsException catch (e) {
      Get.defaultDialog(
        title: 'Gagal!',
        content: Text(e.cause),
      );
    } catch (e) {
      //
    } finally {
      isUploadingData.value = false;
    }
  }
}
