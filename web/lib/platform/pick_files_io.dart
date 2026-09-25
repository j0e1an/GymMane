import 'picked_local.dart';

/// File dialogs for this project run in the browser. Tests and other VM
/// builds get an empty result.
Future<PickedLocal?> pickLocalFile({String accept = ''}) async => null;

Future<List<PickedLocal>> pickLocalFiles({String accept = ''}) async => const [];
