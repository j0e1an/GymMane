import 'dart:typed_data';

class ShotBytes {
  const ShotBytes({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

class CameraStart {
  const CameraStart.native() : pending = null;

  const CameraStart.web(this.pending);

  final Future<ShotBytes?>? pending;
}
