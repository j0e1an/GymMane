import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class Platform {
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isWindows = false;
  static const bool isFuchsia = false;
}

final Map<String, Uint8List> _files = {};
final Set<String> _dirs = {};
web.IDBDatabase? _db;
Future<void>? _opening;

Future<void> ensureFileStore() {
  return _opening ??= _open();
}

Future<void> _open() async {
  try {
    final db = await _openDb();
    _db = db;
    final loaded = await _loadAll(db);
    for (final entry in loaded.entries) {
      _files.putIfAbsent(entry.key, () => entry.value);
    }
  } catch (_) {
    _db = null;
  }
}

class FileSystemEntity {
  FileSystemEntity(this.path);
  final String path;
}

class File extends FileSystemEntity {
  File(super.path);

  bool existsSync() => _files.containsKey(path);

  Future<bool> exists() async => existsSync();

  Future<Uint8List> readAsBytes() async {
    final cached = _files[path];
    if (cached != null) return Uint8List.fromList(cached);
    final fetched = await _tryFetch(path);
    if (fetched != null) return fetched;
    throw StateError('File not found: $path');
  }

  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {
    final data = Uint8List.fromList(bytes);
    _files[path] = data;
    await _idbPut(path, data);
  }

  Future<void> writeAsString(String contents, {bool flush = false}) =>
      writeAsBytes(utf8.encode(contents), flush: flush);

  Future<File> copy(String newPath) async {
    final dest = File(newPath);
    await dest.writeAsBytes(await readAsBytes(), flush: true);
    return dest;
  }

  Future<void> delete({bool recursive = false}) async {
    _files.remove(path);
    await _idbDelete(path);
  }

  Future<int> length() async => (await readAsBytes()).length;
}

class Directory extends FileSystemEntity {
  Directory(super.path);

  bool existsSync() {
    if (_dirs.contains(path)) return true;
    final prefix = path.endsWith('/') ? path : '$path/';
    return _files.keys.any((key) => key.startsWith(prefix));
  }

  Future<bool> exists() async => existsSync();

  Future<Directory> create({bool recursive = false}) async {
    if (!recursive) {
      _dirs.add(path);
      return this;
    }
    final parts = path.split('/').where((part) => part.isNotEmpty);
    var acc = path.startsWith('/') ? '' : '';
    for (final part in parts) {
      acc = '$acc/$part';
      _dirs.add(acc);
    }
    return this;
  }

  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    final prefix = path.endsWith('/') ? path : '$path/';
    final out = <FileSystemEntity>[];
    for (final key in _files.keys) {
      if (!key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      if (!recursive && rest.contains('/')) continue;
      out.add(File(key));
    }
    return out;
  }
}

Future<Uint8List?> _tryFetch(String path) async {
  if (!path.startsWith('blob:') && !path.startsWith('http:') && !path.startsWith('https:')) {
    return null;
  }
  final response = await web.window.fetch(path.toJS).toDart;
  if (!response.ok) return null;
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

Future<web.IDBDatabase> _openDb() {
  final done = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open('gymmane-files', 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains('files')) db.createObjectStore('files');
  }).toJS;
  request.onsuccess = ((web.Event _) {
    if (!done.isCompleted) done.complete(request.result as web.IDBDatabase);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError(request.error ?? 'indexedDB open');
  }).toJS;
  return done.future;
}

Future<JSAny?> _result(web.IDBRequest request) {
  final done = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError(request.error ?? 'indexedDB');
  }).toJS;
  return done.future;
}

Future<Map<String, Uint8List>> _loadAll(web.IDBDatabase db) async {
  final store = db.transaction('files'.toJS, 'readonly').objectStore('files');
  final keys = await _result(store.getAllKeys());
  final values = await _result(store.getAll());
  final keyList = _asList(keys);
  final valueList = _asList(values);
  final out = <String, Uint8List>{};
  final n = keyList.length < valueList.length ? keyList.length : valueList.length;
  for (var i = 0; i < n; i++) {
    final key = keyList[i];
    final value = valueList[i];
    if (key == null || value == null) continue;
    out[(key as JSString).toDart] = _bytesOf(value);
  }
  return out;
}

List<JSAny?> _asList(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) return const [];
  return (value as JSArray<JSAny?>).toDart;
}

Uint8List _bytesOf(JSAny value) {
  try {
    return (value as JSUint8Array).toDart;
  } catch (_) {
    return (value as JSArrayBuffer).toDart.asUint8List();
  }
}

Future<void> _idbPut(String path, Uint8List bytes) async {
  final db = _db;
  if (db == null) return;
  try {
    final store = db.transaction('files'.toJS, 'readwrite').objectStore('files');
    await _result(store.put(bytes.toJS, path.toJS));
  } catch (_) {}
}

Future<void> _idbDelete(String path) async {
  final db = _db;
  if (db == null) return;
  try {
    final store = db.transaction('files'.toJS, 'readwrite').objectStore('files');
    await _result(store.delete(path.toJS));
  } catch (_) {}
}
