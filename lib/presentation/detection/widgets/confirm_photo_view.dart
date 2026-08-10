import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/buttons.dart';
import '../../design/tokens.dart';
import '../detection_view_model.dart';

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
    this.frameCheck = FrameCheck.none,
    this.frameSummary,
  });

  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  final FrameCheck frameCheck;
  final String? frameSummary;

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

            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.md),
            FrameCheckNote(check: frameCheck, summary: frameSummary),
            const SizedBox(height: AppSpacing.md),
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

/// What the on-device model saw, before anything was uploaded.
///
/// The second line is not padding. The detector recognises COCO object
/// categories — "bottle", "book", "cell phone" — and cannot name a product;
/// that is the cloud step's job. Showing "Bottle in frame" without saying so
/// would read as the app having identified the item, which is precisely the
/// overclaim the badges elsewhere exist to prevent. The check earns its place
/// by answering a different and genuinely useful question: is this photograph
/// worth sending at all?
class FrameCheckNote extends StatelessWidget {
  const FrameCheckNote({super.key, required this.check, this.summary});

  final FrameCheck check;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    // Nothing to say, and nothing said. A detector that failed to load is not
    // the user's problem and must not be dressed up as a framing complaint.
    if (check == FrameCheck.none || check == FrameCheck.unavailable) {
      return const SizedBox.shrink();
    }

    final (IconData icon, String title, String detail) = switch (check) {
      FrameCheck.running => (
          Icons.hourglass_empty,
          'Checking the photo',
          'Running on your device. Nothing has been uploaded yet.',
        ),
      FrameCheck.found => (
          Icons.center_focus_strong_outlined,
          summary ?? 'Object in frame',
          'Found on your device. An object category, not the product — that '
              'comes from the next step.',
        ),
      FrameCheck.empty => (
          Icons.filter_center_focus,
          'No object recognised',
          'You can still analyse it. Filling more of the frame, or more '
              'light, usually helps.',
        ),
      _ => (Icons.info_outline, '', ''),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(detail, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
