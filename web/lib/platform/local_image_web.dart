import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'gym_io_web.dart';

class LocalImage extends StatefulWidget {
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
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> {
  Uint8List? _bytes;
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _error = null;
      });
    } catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _error = error;
        _stack = stack;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      final builder = widget.errorBuilder;
      if (builder != null) return builder(context, error, _stack);
      return SizedBox(width: widget.width, height: widget.height);
    }
    final bytes = _bytes;
    if (bytes == null) {
      final child = SizedBox(width: widget.width, height: widget.height);
      final frame = widget.frameBuilder;
      if (frame != null) return frame(context, child, null, false);
      return child;
    }
    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: widget.gaplessPlayback,
      filterQuality: widget.filterQuality,
      cacheWidth: widget.cacheWidth,
      frameBuilder: widget.frameBuilder,
      errorBuilder: widget.errorBuilder,
    );
  }
}
