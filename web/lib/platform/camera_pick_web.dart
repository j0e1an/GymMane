import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'shot_bytes.dart';
import 'temp_file.dart';

CameraStart beginCameraPick({double? maxWidth, double? maxHeight, int? imageQuality}) {
  final done = Completer<ShotBytes?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  if (_phone) input.setAttribute('capture', 'environment');
  web.document.body?.append(input);

  var settled = false;
  late final JSFunction onFocus;

  void finish(web.File? file) {
    if (settled) return;
    settled = true;
    web.window.removeEventListener('focus', onFocus);
    input.remove();
    if (!done.isCompleted) {
      if (file == null) {
        done.complete(null);
      } else {
        done.complete(_read(file));
      }
    }
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final list = input.files;
      web.File? file;
      if (list != null && list.length > 0) file = list.item(0);
      finish(file);
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  onFocus = ((web.Event _) {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!settled) finish(null);
    });
  }).toJS;
  web.window.addEventListener('focus', onFocus);
  input.click();
  return CameraStart.web(done.future);
}

bool get _phone {
  try {
    final coarse = web.window.matchMedia('(pointer: coarse)').matches;
    return coarse && web.window.navigator.maxTouchPoints > 0;
  } catch (_) {
    return false;
  }
}

Future<ShotBytes?> _read(web.File file) async {
  try {
    final buffer = await file.arrayBuffer().toDart;
    final bytes = buffer.toDart.asUint8List();
    final name = file.name.isEmpty ? 'photo.jpg' : file.name;
    final path = await localPathFor(bytes: bytes, name: name);
    if (path == null) return null;
    return ShotBytes(path: path, bytes: bytes);
  } catch (_) {
    return null;
  }
}
