import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String> createExportDir(String folderName) async {
  Directory dir;
  if (Platform.isAndroid) {
    dir = Directory('/storage/emulated/0/Fasih Converter/$folderName');
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
