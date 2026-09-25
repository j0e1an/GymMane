import 'dart:io';

import 'package:video_player/video_player.dart';

export 'package:video_player/video_player.dart';

Future<VideoPlayerController> openLocalVideo(String path) async =>
    VideoPlayerController.file(File(path));
