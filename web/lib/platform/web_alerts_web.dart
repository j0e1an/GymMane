import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'web_session.dart';

class WebAlerts {
  static final Map<int, Timer> _timers = {};
  static bool _restored = false;

  static bool get allowed {
    try {
      return web.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  static bool get pageHidden {
    try {
      return web.document.visibilityState != 'visible';
    } catch (_) {
      return false;
    }
  }

  /// Starts the browser prompt before the first await so a tap can grant it.
  static Future<bool> request() {
    try {
      final pending = web.Notification.requestPermission();
      return pending.toDart.then((value) => value.toDart == 'granted');
    } catch (_) {
      return Future.value(false);
    }
  }

  static Future<void> restore() async {
    if (_restored || !allowed) return;
    _restored = true;
    final saved = _read();
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = <String, Map<String, dynamic>>{};
    saved.forEach((key, value) {
      if (value is! Map) return;
      final at = (value['at'] as num?)?.toInt() ?? 0;
      if (at <= now) {
        due[key] = value.cast<String, dynamic>();
      }
    });
    for (final entry in due.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) continue;
      final item = entry.value;
      await showNow(
        id: id,
        title: item['title'] as String? ?? 'GymMane',
        body: item['body'] as String? ?? '',
        vibrate: item['vibrate'] == true,
        silent: item['silent'] == true,
        tag: 'due-$id',
      );
      _forget(id);
    }
    saved.forEach((key, value) {
      if (due.containsKey(key) || value is! Map) return;
      final id = int.tryParse(key);
      final at = (value['at'] as num?)?.toInt();
      if (id == null || at == null) return;
      _arm(
        id: id,
        title: value['title'] as String? ?? 'GymMane',
        body: value['body'] as String? ?? '',
        when: DateTime.fromMillisecondsSinceEpoch(at),
        vibrate: value['vibrate'] == true,
        silent: value['silent'] == true,
        onlyWhenHidden: value['onlyWhenHidden'] == true,
      );
    });
  }

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool vibrate = false,
    bool silent = false,
    bool persist = true,
    bool onlyWhenHidden = false,
  }) async {
    await restore();
    if (persist) {
      _remember(id, title, body, when, vibrate, silent, onlyWhenHidden);
    } else {
      _forget(id);
    }
    if (!when.isAfter(DateTime.now())) {
      if (onlyWhenHidden && !pageHidden) {
        await cancel(id);
        return;
      }
      await showNow(id: id, title: title, body: body, vibrate: vibrate, silent: silent);
      _forget(id);
      return;
    }
    _arm(
      id: id,
      title: title,
      body: body,
      when: when,
      vibrate: vibrate,
      silent: silent,
      onlyWhenHidden: onlyWhenHidden,
    );
  }

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    bool vibrate = false,
    bool silent = false,
    String? tag,
  }) async {
    _timers.remove(id)?.cancel();
    await _post({
      'type': 'show',
      'id': id,
      'tag': tag,
      'title': title,
      'body': body,
      'vibrate': vibrate ? _buzz : null,
      'silent': silent,
    });
  }

  static Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
    _forget(id);
    await _post({'type': 'cancel', 'id': id});
  }

  static void vibrate(List<int> pattern) {
    try {
      final js = pattern.map((n) => n.toJS).toList().toJS;
      web.window.navigator.vibrate(js);
    } catch (_) {}
  }

  /// Vibration API pattern: vibrate, pause, vibrate. The leading 0 on Android is a delay.
  static const _buzz = [350, 180, 350, 180, 600];

  static const _maxPageTimer = Duration(days: 20);
  static const _maxWorkerTimer = Duration(minutes: 10);

  static void _arm({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required bool vibrate,
    required bool silent,
    required bool onlyWhenHidden,
  }) {
    _timers.remove(id)?.cancel();
    final delay = when.difference(DateTime.now());
    final wait = delay.isNegative ? Duration.zero : delay;
    if (wait <= _maxPageTimer) {
      _timers[id] = Timer(wait, () {
        _timers.remove(id);
        if (onlyWhenHidden && !pageHidden) {
          cancel(id);
          return;
        }
        if (!allowed) return;
        showNow(id: id, title: title, body: body, vibrate: vibrate, silent: silent);
        _forget(id);
      });
    }
    if (wait <= _maxWorkerTimer) {
      _post({
        'type': 'schedule',
        'id': id,
        'title': title,
        'body': body,
        'at': when.millisecondsSinceEpoch,
        'vibrate': vibrate ? _buzz : null,
        'silent': silent,
        'onlyWhenHidden': onlyWhenHidden,
      });
    }
  }

  static Future<void> _post(Map<String, Object?> message) async {
    try {
      final reg = await web.window.navigator.serviceWorker.register('/gymmane_sw.js'.toJS).toDart;
      final ready = await web.window.navigator.serviceWorker.ready.toDart;
      final worker = ready.active ?? reg.active ?? reg.installing ?? reg.waiting;
      worker?.postMessage(jsonEncode(message).toJS);
    } catch (_) {}
  }

  static String get _key => 'gymmane_notify_${WebSession.userId ?? 'local'}';

  static Map<String, dynamic> _read() {
    try {
      final raw = web.window.localStorage.getItem(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  static void _write(Map<String, dynamic> data) {
    try {
      if (data.isEmpty) {
        web.window.localStorage.removeItem(_key);
      } else {
        web.window.localStorage.setItem(_key, jsonEncode(data));
      }
    } catch (_) {}
  }

  static void _remember(
    int id,
    String title,
    String body,
    DateTime when,
    bool vibrate,
    bool silent,
    bool onlyWhenHidden,
  ) {
    final data = _read();
    data['$id'] = {
      'title': title,
      'body': body,
      'at': when.millisecondsSinceEpoch,
      'vibrate': vibrate,
      'silent': silent,
      'onlyWhenHidden': onlyWhenHidden,
    };
    _write(data);
  }

  static void _forget(int id) {
    final data = _read();
    if (data.remove('$id') != null) _write(data);
  }
}
