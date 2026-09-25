import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'gym_io_web.dart';

enum ReleaseMode { stop, release, loop }

enum PlayerMode { mediaPlayer, lowLatency }

enum AndroidContentType { sonification, music, speech }

enum AndroidUsageType { notification, alarm, media }

enum AndroidAudioFocus { gainTransientMayDuck, gain }

enum AVAudioSessionCategory { ambient, playback }

enum AVAudioSessionOptions { mixWithOthers, duckOthers }

class AudioContextAndroid {
  const AudioContextAndroid({
    this.isSpeakerphoneOn,
    this.stayAwake,
    this.contentType,
    this.usageType,
    this.audioFocus,
  });

  final bool? isSpeakerphoneOn;
  final bool? stayAwake;
  final AndroidContentType? contentType;
  final AndroidUsageType? usageType;
  final AndroidAudioFocus? audioFocus;
}

class AudioContextIOS {
  const AudioContextIOS({
    this.category = AVAudioSessionCategory.playback,
    this.options = const {},
  });

  final AVAudioSessionCategory category;
  final Set<AVAudioSessionOptions> options;
}

class AudioContext {
  const AudioContext({this.android, this.iOS});

  final AudioContextAndroid? android;
  final AudioContextIOS? iOS;
}

abstract class Source {
  Future<String> resolve();
}

class DeviceFileSource extends Source {
  DeviceFileSource(this.path, {this.mimeType});

  final String path;
  final String? mimeType;

  @override
  Future<String> resolve() async {
    if (path.startsWith('blob:') || path.startsWith('http:') || path.startsWith('https:')) {
      return path;
    }
    final bytes = await File(path).readAsBytes();
    final type = mimeType ?? _audioMime(path);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    return web.URL.createObjectURL(blob);
  }
}

class AssetSource extends Source {
  AssetSource(this.path, {this.mimeType});

  final String path;
  final String? mimeType;

  @override
  Future<String> resolve() async => 'assets/$path';
}

class AudioPlayer {
  web.HTMLAudioElement? _el;

  web.HTMLAudioElement _ensure() => _el ??= web.HTMLAudioElement();

  Future<void> setReleaseMode(ReleaseMode mode) async {
    _ensure().loop = mode == ReleaseMode.loop;
  }

  Future<void> setPlayerMode(PlayerMode mode) async {}

  Future<void> setAudioContext(AudioContext ctx) async {}

  Future<void> setSource(Source source) async {
    final el = _ensure();
    final ready = Completer<void>();
    el.onloadedmetadata = ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS;
    el.onerror = ((web.Event _) {
      if (!ready.isCompleted) ready.completeError(StateError('audio'));
    }).toJS;
    el.src = await source.resolve();
    el.load();
    await ready.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  Future<void> stop() async {
    final el = _el;
    if (el == null) return;
    el.pause();
    el.currentTime = 0;
  }

  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    await setSource(source);
    final el = _ensure();
    if (volume != null) el.volume = volume;
    await el.play().toDart;
  }

  Future<Duration?> getDuration() async {
    final el = _el;
    if (el == null) return null;
    final seconds = el.duration;
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> release() async {
    final el = _el;
    if (el == null) return;
    el.pause();
    el.removeAttribute('src');
    _el = null;
  }

  Future<void> dispose() => release();
}

String _audioMime(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'm4a' || 'aac' => 'audio/mp4',
    'flac' => 'audio/flac',
    'opus' => 'audio/opus',
    _ => 'audio/mpeg',
  };
}
