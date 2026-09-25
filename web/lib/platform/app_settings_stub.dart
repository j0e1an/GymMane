enum AppSettingsType { settings, notification }

class AppSettings {
  static Future<void> openAppSettings({
    AppSettingsType type = AppSettingsType.settings,
    bool asAnotherTask = false,
  }) async {}
}
