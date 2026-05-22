import 'package:file_picker/file_picker.dart';
import 'package:json_converter/app/data/models/fasih_record.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';

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
  final bool isExporting;
  final bool isUploading;

  const HomeFileLoaded({
    required this.file,
    required this.template,
    required this.records,
    this.isExporting = false,
    this.isUploading = false,
  });

  HomeFileLoaded copyWith({
    PlatformFile? file,
    FasihTemplate? template,
    List<FasihRecord>? records,
    bool? isExporting,
    bool? isUploading,
  }) =>
      HomeFileLoaded(
        file: file ?? this.file,
        template: template ?? this.template,
        records: records ?? this.records,
        isExporting: isExporting ?? this.isExporting,
        isUploading: isUploading ?? this.isUploading,
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
