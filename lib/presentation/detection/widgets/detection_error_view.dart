import 'package:flutter/material.dart';

import '../../design/buttons.dart';
import '../../design/tokens.dart';

/// What the scan tab shows when the analysis failed.
///
/// [message] comes from `mapToUserMessage`, which already produces a sentence
/// naming the specific failure — a timeout, a refused connection, a 500. This
/// widget deliberately does not wrap it in a generic headline that contradicts
/// it: the heading states the outcome, the message states the cause, and the
/// buttons are the fix.
class DetectionErrorView extends StatelessWidget {
  const DetectionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onPickFromGallery,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: _ErrorMark(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'The scan did not go through',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.isNotEmpty
                ? message
                : 'The photo could not be analysed. Try again in a moment.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Try again',
            icon: Icons.photo_camera_outlined,
            onPressed: onRetry,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Choose a photo',
            icon: Icons.photo_library_outlined,
            onPressed: onPickFromGallery,
          ),
        ],
      ),
    );
  }
}

class _ErrorMark extends StatelessWidget {
  const _ErrorMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.negativeSurface,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.cloud_off_outlined,
        size: 34,
        color: AppColors.negative,
      ),
    );
  }
}
