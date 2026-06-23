import 'dart:io';

import 'package:flutter/foundation.dart';

class ErrorReport {
  final DateTime timestamp;
  final String error;
  final StackTrace stackTrace;
  final Map<String, String> context;

  const ErrorReport({
    required this.timestamp,
    required this.error,
    required this.stackTrace,
    this.context = const {},
  });
}

class AppErrorLogger extends ChangeNotifier {
  AppErrorLogger._();

  static final AppErrorLogger instance = AppErrorLogger._();

  static const _max = 50;
  final _reports = <ErrorReport>[];
  List<ErrorReport> get reports => List.unmodifiable(_reports);

  void log(
    Object error,
    StackTrace stackTrace, {
    Map<String, String> context = const {},
  }) {
    _reports.add(
      ErrorReport(
        timestamp: DateTime.now(),
        error: error.toString(),
        stackTrace: stackTrace,
        context: context,
      ),
    );
    if (_reports.length > _max) _reports.removeAt(0);
    debugPrint('[AppError] $error\n$stackTrace');
    notifyListeners();
  }

  void clear() {
    _reports.clear();
    notifyListeners();
  }

  static String formatReport(ErrorReport r, {String appVersion = ''}) {
    final buf = StringBuffer()
      ..writeln('FASIH CONVERTER — ERROR REPORT')
      ..writeln('=' * 40)
      ..writeln('Waktu    : ${r.timestamp.toIso8601String()}');
    if (appVersion.isNotEmpty) buf.writeln('Aplikasi : $appVersion');
    try {
      buf.writeln(
        'Platform : ${Platform.operatingSystem}'
        ' — ${Platform.operatingSystemVersion}',
      );
    } catch (_) {}
    if (r.context.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('KONTEKS')
        ..writeln('-' * 30);
      for (final e in r.context.entries) {
        buf.writeln('${e.key.padRight(22)}: ${e.value}');
      }
    }
    buf
      ..writeln()
      ..writeln('ERROR')
      ..writeln('-' * 30)
      ..writeln(r.error)
      ..writeln()
      ..writeln('STACK TRACE')
      ..writeln('-' * 30)
      ..writeln(r.stackTrace);
    return buf.toString();
  }
}
