import 'package:flutter/material.dart';

import '../../design/buttons.dart';
import '../../design/segmented_control.dart';
import '../../design/tokens.dart';
import 'scan_frame.dart';

/// The two ways to read a product, which are not two ways of doing the same
/// thing.
enum ScanMode { photo, barcode }

/// The idle state of the scan tab: what the user sees before anything happens.
///
/// It carries one job beyond starting a scan, and it is why the caption is not
/// marketing copy. This screen is the only place the app can set the
/// expectation *before* a result exists. Told here that a photo produces a
/// guess and a barcode produces a lookup, the badges on the result screen
/// confirm something the user already knows. Told only there, they read as
/// hedging after the fact.
///
/// The mode switch is a segmented control rather than two buttons for the same
/// reason. Two buttons say "two actions"; a segmented control says "these are
/// alternatives, and they differ" — which is the thing worth learning, because
/// one of them is reproducible and the other is not.
class ScanHomeView extends StatelessWidget {
  const ScanHomeView({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onOpenCamera,
    required this.onPickFromGallery,
    required this.onScanBarcode,
    this.isBusy = false,
  });

  final ScanMode mode;
  final ValueChanged<ScanMode> onModeChanged;
  final VoidCallback onOpenCamera;
  final VoidCallback onPickFromGallery;
  final VoidCallback onScanBarcode;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isPhoto = mode == ScanMode.photo;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSegmentedControl<ScanMode>(
            value: mode,
            onChanged: onModeChanged,
            options: const [
              SegmentOption(
                value: ScanMode.photo,
                label: 'Photo',
                icon: Icons.photo_camera_outlined,
              ),
              SegmentOption(
                value: ScanMode.barcode,
                label: 'Barcode',
                icon: Icons.qr_code_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: ScanFrame()),
          const SizedBox(height: AppSpacing.xl),
          Text(
            isPhoto ? 'Photograph the product' : 'Scan the barcode',
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isPhoto
                // Names the ceiling of this mode up front. A user who knows
                // the answer is a guess reads the Estimated badges as
                // confirmation rather than as the app backing away from
                // something it already said.
                ? 'A model reads the packaging. Everything it returns is an '
                    'estimate, and the result marks it as one.'
                : 'The digits resolve against the GS1 registry and the Open '
                    'Food Facts database. The same barcode gives the same '
                    'answer every time.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (isPhoto) ...[
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
          ] else
            AppPrimaryButton(
              label: 'Scan barcode',
              icon: Icons.qr_code_scanner,
              onPressed: isBusy ? null : onScanBarcode,
            ),
        ],
      ),
    );
  }
}
