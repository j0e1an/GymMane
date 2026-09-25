import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.WakeLockSentinel? _sentinel;
bool _want = false;
bool _listening = false;

Future<void> setWakeLock(bool on) async {
  _want = on;
  _listen();
  if (on) {
    await _acquire();
  } else {
    await _release();
  }
}

void _listen() {
  if (_listening) return;
  _listening = true;
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (_want && web.document.visibilityState == 'visible') {
        _acquire();
      }
    }).toJS,
  );
}

Future<void> _acquire() async {
  if (!_want) return;
  if (_sentinel != null && !_sentinel!.released) return;
  try {
    _sentinel = await web.window.navigator.wakeLock.request('screen').toDart;
  } catch (_) {
    _sentinel = null;
  }
}

Future<void> _release() async {
  final held = _sentinel;
  _sentinel = null;
  if (held == null) return;
  try {
    await held.release().toDart;
  } catch (_) {}
}
