import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a chosen avatar — either one of the bundled `assets/avatars/...`
/// options, or an absolute file path from the user's own photo library.
class AvatarThumb extends StatelessWidget {
  const AvatarThumb({super.key, required this.source, required this.size, this.grey = false});

  final String source;
  final double size;

  /// Drain the picture to greyscale (a blend on the image itself, no layer).
  final bool grey;

  @override
  Widget build(BuildContext context) {
    // [size] can be infinite ("fill the space", as in the avatar picker
    // grid) — then the real size comes from the layout.
    if (!size.isFinite) {
      return LayoutBuilder(builder: (context, constraints) => _build(context, constraints.biggest.shortestSide));
    }
    return _build(context, size);
  }

  Widget _build(BuildContext context, double side) {
    final color = grey ? Colors.grey : null;
    final blend = grey ? BlendMode.saturation : null;
    // Decoded at the size it's drawn, not the file's: a gallery photo can be
    // 4000 px (~48 MB once decoded) for a 46 px circle. Left to the file's
    // own size only if the layout gives no bound at all.
    final pixels = side.isFinite ? (side * MediaQuery.devicePixelRatioOf(context)).round() : null;
    final image = source.startsWith('assets/')
        ? Image.asset(
            source,
            width: side.isFinite ? side : null,
            height: side.isFinite ? side : null,
            cacheWidth: pixels,
            fit: BoxFit.cover,
            color: color,
            colorBlendMode: blend,
          )
        : Image.file(
            File(source),
            width: side.isFinite ? side : null,
            height: side.isFinite ? side : null,
            cacheWidth: pixels,
            fit: BoxFit.cover,
            color: color,
            colorBlendMode: blend,
          );
    return ClipOval(child: image);
  }
}
