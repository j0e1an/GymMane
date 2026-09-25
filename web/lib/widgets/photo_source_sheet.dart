import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../platform/camera_pick.dart';
import '../platform/temp_file.dart';
import '../theme/app_colors.dart';
import 'glass.dart';
import 'ui_kit.dart';

class PhotoChoice {
  const PhotoChoice(this.source, {this.camera});

  final ImageSource source;
  final Future<ShotBytes?>? camera;
}

Future<PhotoChoice?> pickPhotoSource(
  BuildContext context, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) =>
    showAppSheet<PhotoChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoSourceSheet(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      ),
    );

Future<ShotBytes?> loadPickedPhoto(
  PhotoChoice choice, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  final pending = choice.camera;
  if (pending != null) return pending;
  final shot = await ImagePicker().pickImage(
    source: choice.source,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
  );
  if (shot == null) return null;
  final bytes = await shot.readAsBytes();
  final path = await localPathFor(path: shot.path, bytes: bytes, name: shot.name);
  if (path == null) return null;
  return ShotBytes(path: path, bytes: bytes);
}

class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({
    super.key,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
  });

  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Container(
      padding: sheetPad(context),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          OptionGroup([
            OptionItem(
              t.takePhoto,
              icon: PhosphorIconsRegular.camera,
              onTap: () {
                final start = beginCameraPick(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                  imageQuality: imageQuality,
                );
                Navigator.of(context).pop(PhotoChoice(ImageSource.camera, camera: start.pending));
              },
            ),
            OptionItem(
              t.chooseGallery,
              icon: PhosphorIconsRegular.image,
              onTap: () => Navigator.of(context).pop(const PhotoChoice(ImageSource.gallery)),
            ),
          ]),
        ],
      ),
    );
  }
}
