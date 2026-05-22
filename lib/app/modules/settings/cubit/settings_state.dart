sealed class SettingsState {
  const SettingsState();
}

class SettingsInitial extends SettingsState {
  final String sheetId;
  final bool hasCredentials;

  const SettingsInitial({
    this.sheetId = '',
    this.hasCredentials = false,
  });
}

class SettingsSaving extends SettingsState {
  const SettingsSaving();
}

class SettingsSaved extends SettingsState {
  const SettingsSaved();
}
