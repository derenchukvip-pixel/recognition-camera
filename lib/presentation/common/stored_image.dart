import 'dart:io';

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// The photo a stored scan points at, or null.
///
/// Two paths are tried because the record keeps two: the copy the app made,
/// and the original the camera or picker produced. The copy is the one the OS
/// clears first when it reclaims space, and the original often outlives it.
///
/// Null is a real answer here, not a failure. A barcode scan never had a
/// photograph, and the caller renders that case differently from a photo that
/// has gone missing.
File? storedImageFile(String imagePath, String originalImagePath) {
  for (final path in [imagePath, originalImagePath]) {
    if (path.isEmpty) continue;
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

/// Full-size version for the result screen, which needs something in the frame
/// even when the file is gone.
Widget storedImage(String imagePath, String originalImagePath) {
  final file = storedImageFile(imagePath, originalImagePath);
  if (file != null) return Image.file(file, fit: BoxFit.cover);
  return const ColoredBox(
    color: AppColors.surfaceSubtle,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.inkMuted,
      ),
    ),
  );
}

/// Thumbnail builder for a list row, or null when there is no photo to show.
WidgetBuilder? storedThumbnailBuilder(
  String imagePath,
  String originalImagePath,
) {
  final file = storedImageFile(imagePath, originalImagePath);
  if (file == null) return null;
  return (_) => Image.file(file, fit: BoxFit.cover);
}
