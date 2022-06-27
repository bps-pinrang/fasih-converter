import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<String> createFolderInAppDocDir(String folderName) async {
  //Get this App Document Directory

  final path = Directory('storage/emulated/0/Fasih Converter/$folderName');
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }

  status = await Permission.manageExternalStorage.status;
  if(!status.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if ((await path.exists())) {
    return path.path;
  } else {
    path.create(recursive: true);
    return path.path;
  }
}