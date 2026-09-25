import 'dart:typed_data';

class PickedLocal {
  const PickedLocal({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;
  final String? path;
}
