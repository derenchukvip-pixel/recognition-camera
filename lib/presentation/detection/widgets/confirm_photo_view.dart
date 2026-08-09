import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/buttons.dart';
import '../../design/tokens.dart';

/// Shown between the shutter and the result: the photo that is about to be
/// analysed, and a way out.
///
/// The step earns its place because recognition quality is almost entirely a
/// function of the photo, and the user is the only one who can tell that the
/// label is out of frame. Analysis has already started in the background by
/// the time this appears — confirming does not queue work, it reveals work
/// that is already underway.
class ConfirmPhotoView extends StatelessWidget {
  const ConfirmPhotoView({
    super.key,
    required this.imageFile,
    required this.onConfirm,
    required this.onRetake,
  });

  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Use this photo?', style: AppText.display),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'A readable label and a straight angle are most of the accuracy.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: AppRadius.cardRadius,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.file(imageFile, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Retake',
                    onPressed: onRetake,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Analyse',
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
