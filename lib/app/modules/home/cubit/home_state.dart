import 'package:file_picker/file_picker.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/services/fasih_backup_writer.dart';

sealed class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoadingFile extends HomeState {
  const HomeLoadingFile();
}

class HomeFileLoaded extends HomeState {
  final PlatformFile file;
  final FasihTemplate template;
  final List<FasihRecord> records;
  final List<RespondentMeta> respondentMeta;
  final String envJson;
  final bool isExporting;
  final bool isUploading;
  final bool isImporting;

  const HomeFileLoaded({
    required this.file,
    required this.template,
    required this.records,
    required this.respondentMeta,
    required this.envJson,
    this.isExporting = false,
    this.isUploading = false,
    this.isImporting = false,
  });

  HomeFileLoaded copyWith({
    PlatformFile? file,
    FasihTemplate? template,
    List<FasihRecord>? records,
    List<RespondentMeta>? respondentMeta,
    String? envJson,
    bool? isExporting,
    bool? isUploading,
    bool? isImporting,
  }) =>
      HomeFileLoaded(
        file: file ?? this.file,
        template: template ?? this.template,
        records: records ?? this.records,
        respondentMeta: respondentMeta ?? this.respondentMeta,
        envJson: envJson ?? this.envJson,
        isExporting: isExporting ?? this.isExporting,
        isUploading: isUploading ?? this.isUploading,
        isImporting: isImporting ?? this.isImporting,
      );
}

class HomeMultiTemplate extends HomeState {
  final PlatformFile file;
  final List<FasihTemplate> templates;

  const HomeMultiTemplate({required this.file, required this.templates});
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);
}
