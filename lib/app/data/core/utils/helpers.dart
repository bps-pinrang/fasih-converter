import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String> createExportDir(String folderName) async {
  Directory dir;
  if (Platform.isAndroid) {
    dir = Directory('storage/emulated/0/Fasih Converter/$folderName');
    final storageStatus = await Permission.manageExternalStorage.status;
    if (!storageStatus.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    dir = Directory('${appDir.path}/$folderName');
  }

  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<void> showLoadingDialog({String? label, RxDouble? progress}) async {
  if (Get.isSnackbarOpen || (Get.isDialogOpen ?? false)) {
    Get.back();
  }

  return Get.defaultDialog(
    title: 'Mohon Tunggu',
    titleStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    barrierDismissible: false,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SpinKitFadingCircle(color: Colors.blueAccent, size: 30.0),
            const SizedBox(width: 8),
            Text(label ?? 'Memuat data...'),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 16),
          Obx(
            () => LinearPercentIndicator(
              percent: progress / 100,
              backgroundColor: Colors.green.shade100,
              progressColor: Colors.green.shade500,
              animateFromLastPercent: true,
              animation: true,
              animationDuration: 100,
              barRadius: const Radius.circular(12),
            ),
          ),
          const SizedBox(height: 4),
          Obx(
            () => Text(
              '${progress.value.toPrecision(0)}%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ],
    ),
  );
}
