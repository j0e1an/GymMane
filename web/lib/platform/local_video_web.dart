import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'gym_io_web.dart';

class VideoPlayerValue {
  const VideoPlayerValue({this.size = Size.zero, this.isPlaying = false});

  final Size size;
  final bool isPlaying;

  double get aspectRatio {
    if (size.height == 0) return 1;
    return size.width / size.height;
  }
}

class VideoPlayerController {
  VideoPlayerController._(this._url);

  final String _url;
  final String viewType = 'gm-video-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
  static int _seq = 0;

  web.HTMLVideoElement? element;
  bool registered = false;
  VideoPlayerValue value = const VideoPlayerValue();

  Future<void> initialize() async {
    final el = web.HTMLVideoElement()
      ..preload = 'auto'
      ..controls = false
      ..playsInline = true;
    el.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain';
    final ready = Completer<void>();
    el.onloadedmetadata = ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS;
    el.onerror = ((web.Event _) {
      if (!ready.isCompleted) ready.completeError(StateError('video'));
    }).toJS;
    el.src = _url;
    element = el;
    await ready.future.timeout(const Duration(seconds: 20));
    final width = el.videoWidth.toDouble();
    final height = el.videoHeight.toDouble();
    value = VideoPlayerValue(
      size: Size(width == 0 ? 16 : width, height == 0 ? 9 : height),
      isPlaying: value.isPlaying,
    );
  }

  Future<void> setLooping(bool looping) async {
    element?.loop = looping;
  }

  Future<void> setVolume(double volume) async {
    final el = element;
    if (el == null) return;
    el.volume = volume;
    el.muted = volume == 0;
  }

  Future<void> play() async {
    final el = element;
    if (el == null) return;
    await el.play().toDart;
    value = VideoPlayerValue(size: value.size, isPlaying: true);
  }

  Future<void> pause() async {
    element?.pause();
    value = VideoPlayerValue(size: value.size, isPlaying: false);
  }

  void dispose() {
    final el = element;
    el?.pause();
    el?.removeAttribute('src');
    el?.load();
    element = null;
  }
}

class VideoPlayer extends StatelessWidget {
  const VideoPlayer(this.controller, {super.key});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final el = controller.element;
    if (el == null) return const SizedBox.shrink();
    if (!controller.registered) {
      ui_web.platformViewRegistry.registerViewFactory(controller.viewType, (_) => el);
      controller.registered = true;
    }
    return HtmlElementView(viewType: controller.viewType);
  }
}

Future<VideoPlayerController> openLocalVideo(String path) async {
  final url = await _urlFor(path);
  return VideoPlayerController._(url);
}

Future<String> _urlFor(String path) async {
  if (path.startsWith('blob:') ||
      path.startsWith('http:') ||
      path.startsWith('https:') ||
      path.startsWith('data:')) {
    return path;
  }
  final bytes = await File(path).readAsBytes();
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: _mime(path)));
  return web.URL.createObjectURL(blob);
}

String _mime(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'm4v' || 'mp4' => 'video/mp4',
    _ => 'video/mp4',
  };
}
