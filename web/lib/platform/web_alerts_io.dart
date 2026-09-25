class WebAlerts {
  static bool get allowed => false;

  static bool get pageHidden => false;

  static Future<bool> request() async => false;

  static Future<void> restore() async {}

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool vibrate = false,
    bool silent = false,
    bool persist = true,
    bool onlyWhenHidden = false,
  }) async {}

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    bool vibrate = false,
    bool silent = false,
    String? tag,
  }) async {}

  static Future<void> cancel(int id) async {}

  static void vibrate(List<int> pattern) {}
}
