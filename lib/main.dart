import 'package:flutter/material.dart';
import 'package:json_converter/app/di/injection.dart';
import 'package:json_converter/app/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fasih Converter',
      debugShowCheckedModeBanner: false,
      routerConfig: _router.config(),
    );
  }
}
