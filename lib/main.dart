import 'package:flutter/material.dart';
import 'package:flutter_config/flutter_config.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';

import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterConfig.loadEnvVariables();
  await FasihConverterSheetApi.init();
  runApp(
    const MyApp()
  );
}
    class MyApp extends StatelessWidget {
      const MyApp({super.key});

      @override
      Widget build(BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        return GetMaterialApp(
          title: 'Fasih Converter',
          debugShowCheckedModeBanner: false,
          initialRoute: AppPages.INITIAL,
          getPages: AppPages.routes,
          theme: ThemeData(
            textTheme: GoogleFonts.leagueSpartanTextTheme(textTheme),
          ),
        );
      }
    }

