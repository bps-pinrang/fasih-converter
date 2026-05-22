import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsRepository.init();
  runApp(
    GetMaterialApp(
      title: 'Fasih Converter',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
    ),
  );
}
