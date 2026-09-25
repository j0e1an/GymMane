class WebSession {
  static String? userId;
  static String? email;
  static String? name;

  static void adopt({required String id, String? email, String? name}) {
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    userId = clean.isEmpty ? null : clean;
    WebSession.email = email;
    WebSession.name = name;
  }

  static String scopedDir(String root, String leaf) {
    final id = userId;
    if (id == null || id.isEmpty) return '$root/$leaf';
    return '$root/$id/$leaf';
  }
}
