import 'gym_io_web.dart';

Future<Directory> getApplicationDocumentsDirectory() async {
  await ensureFileStore();
  final dir = Directory('/gymmane/docs');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<Directory> getTemporaryDirectory() async {
  await ensureFileStore();
  final dir = Directory('/gymmane/tmp');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}
