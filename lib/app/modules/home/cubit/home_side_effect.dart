import 'package:json_converter/app/data/models/fasih_template.dart';

sealed class HomeSideEffect {
  const HomeSideEffect();
}

class ShowSnackbar extends HomeSideEffect {
  final String title;
  final String message;
  final bool isError;

  const ShowSnackbar({
    required this.title,
    required this.message,
    this.isError = false,
  });
}

class ShowSuccessDialog extends HomeSideEffect {
  final String title;
  final String message;

  const ShowSuccessDialog({required this.title, required this.message});
}

class ShowTemplatePicker extends HomeSideEffect {
  final List<FasihTemplate> templates;

  const ShowTemplatePicker(this.templates);
}

class ShowImportSuccess extends HomeSideEffect {
  final String outputPath;
  const ShowImportSuccess(this.outputPath);
}
