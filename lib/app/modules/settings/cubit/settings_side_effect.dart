sealed class SettingsSideEffect {
  const SettingsSideEffect();
}

class ShowSettingsSnackbar extends SettingsSideEffect {
  final String title;
  final String message;
  final bool isError;

  const ShowSettingsSnackbar({
    required this.title,
    required this.message,
    this.isError = false,
  });
}
