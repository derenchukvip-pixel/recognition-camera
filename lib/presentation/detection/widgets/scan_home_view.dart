import 'package:flutter/material.dart';

import '../../design/buttons.dart';
import '../../design/tokens.dart';
import 'scan_frame.dart';

/// The idle state of the scan tab: what the user sees before anything happens.
///
/// It carries one job beyond starting a scan, and it is the reason the caption
/// is not marketing copy. This screen is the only place the app can set the
/// expectation *before* a result exists — that a photo produces an estimate,
/// not a fact. Told here, the badges on the result screen confirm something
/// the user already knows. Told only there, they read as hedging.
class ScanHomeView extends StatelessWidget {
  const ScanHomeView({
    super.key,
    required this.onOpenCamera,
    required this.onPickFromGallery,
    this.isBusy = false,
  });

  final VoidCallback onOpenCamera;
  final VoidCallback onPickFromGallery;
  final bool isBusy;

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
          const Center(child: ScanFrame()),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Scan a product',
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Point the camera at the packaging. Anything read from a photo is '
            'an estimate, and every line of the result says so.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Open camera',
            icon: Icons.photo_camera_outlined,
            onPressed: isBusy ? null : onOpenCamera,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Choose a photo',
            icon: Icons.photo_library_outlined,
            onPressed: isBusy ? null : onPickFromGallery,
          ),
        ],
      ),
    );
  }
}
