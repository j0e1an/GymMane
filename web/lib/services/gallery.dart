import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/download.dart';

const _channel = MethodChannel('gymmane/gallery');

Future<bool> saveImageToGallery(Uint8List png, String name) async {
  if (kIsWeb) return downloadBytes(png, name, 'image/png');
  try {
    final ok = await _channel.invokeMethod<bool>('savePng', {'bytes': png, 'name': name});
    return ok ?? false;
  } catch (_) {
    return false;
  }
}
