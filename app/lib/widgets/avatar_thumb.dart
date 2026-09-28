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
    final color = grey ? Colors.grey : null;
    final blend = grey ? BlendMode.saturation : null;
    final image = source.startsWith('assets/')
        ? Image.asset(source, width: size, height: size, fit: BoxFit.cover, color: color, colorBlendMode: blend)
        : Image.file(File(source), width: size, height: size, fit: BoxFit.cover, color: color, colorBlendMode: blend);
    return ClipOval(child: image);
  }
}
