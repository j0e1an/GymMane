import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/gym_io.dart';

class DeviceKind {
  DeviceKind._();

  static const _channel = MethodChannel('gymmane/device');

  static Future<bool> isWatch() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isWatch') ?? false;
    } catch (_) {
      return false;
    }
  }
}
