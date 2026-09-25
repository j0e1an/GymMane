import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_local.dart';

Future<PickedLocal?> pickLocalFile({String accept = ''}) async {
  final files = await _pick(accept: accept, multiple: false);
  if (files.isEmpty) return null;
  return files.first;
}

Future<List<PickedLocal>> pickLocalFiles({String accept = ''}) {
  return _pick(accept: accept, multiple: true);
}

Future<List<PickedLocal>> _pick({required String accept, required bool multiple}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = multiple
    ..accept = accept
    ..style.display = 'none';
  web.document.body?.append(input);

  final done = Completer<List<web.File>>();
  var settled = false;
  late final JSFunction onFocus;

  void finish(List<web.File> files) {
    if (settled) return;
    settled = true;
    web.window.removeEventListener('focus', onFocus);
    input.remove();
    if (!done.isCompleted) done.complete(files);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final list = input.files;
      final out = <web.File>[];
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final item = list.item(i);
          if (item != null) out.add(item);
        }
      }
      finish(out);
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(const [])).toJS);
  onFocus = ((web.Event _) {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!settled) finish(const []);
    });
  }).toJS;
  web.window.addEventListener('focus', onFocus);
  input.click();

  final files = await done.future;
  final picked = <PickedLocal>[];
  for (final file in files) {
    final buffer = await file.arrayBuffer().toDart;
    picked.add(PickedLocal(name: file.name, bytes: buffer.toDart.asUint8List()));
  }
  return picked;
}
