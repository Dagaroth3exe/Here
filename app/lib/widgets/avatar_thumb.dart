import 'dart:io';
import 'package:flutter/material.dart';

/// Renders a chosen avatar — either one of the bundled `assets/avatars/...`
/// options, or an absolute file path from the user's own photo library.
class AvatarThumb extends StatelessWidget {
  const AvatarThumb({super.key, required this.source, required this.size});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = source.startsWith('assets/')
        ? Image.asset(source, width: size, height: size, fit: BoxFit.cover)
        : Image.file(File(source), width: size, height: size, fit: BoxFit.cover);
    return ClipOval(child: image);
  }
}
