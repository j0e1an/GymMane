import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> shareBytes({
  required List<int> bytes,
  required String filename,
  String? mimeType,
  String? subject,
  String? text,
}) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(data, name: filename, mimeType: mimeType)],
      subject: subject,
      text: text,
    ),
  );
}
