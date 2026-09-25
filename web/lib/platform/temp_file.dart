import 'gym_io.dart';
import 'paths.dart';

/// Keeps a filesystem path when the picker has one. When the web picker only
/// returns bytes, writes them into the temp directory so import code can copy
/// the file the same way it does on mobile.
Future<String?> localPathFor({String? path, List<int>? bytes, String name = 'file.bin'}) async {
  if (path != null && path.isNotEmpty) return path;
  if (bytes == null) return null;
  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
