import 'dart:io';

import 'package:flutter/widgets.dart';

class LocalImage extends StatelessWidget {
  const LocalImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.frameBuilder,
    this.errorBuilder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
    );
  }
}
