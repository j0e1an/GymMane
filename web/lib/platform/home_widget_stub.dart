import 'package:flutter/widgets.dart';

class HomeWidget {
  static Future<bool?> setAppGroupId(String groupId) async => false;

  static Future<T?> getWidgetData<T>(String id, {T? defaultValue}) async => defaultValue;

  static Future<bool?> saveWidgetData<T>(String id, T? data) async => false;

  static Future<void> renderFlutterWidget(
    Widget widget, {
    required String key,
    Size logicalSize = const Size(200, 200),
    double pixelRatio = 1,
  }) async {}

  static Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) async =>
      false;

  static Future<bool?> isRequestPinWidgetSupported() async => false;

  static Future<void> requestPinWidget({
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) async {}
}
