import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Covers the scan tab while a lookup is in flight.
///
/// Opaque rather than a scrim: what it covers is the confirm view, and a
/// half-visible "Use this photo?" behind a spinner invites a tap on a button
/// that is no longer live.
///
/// The two variants say what is being waited on, because the two waits are not
/// the same thing and the difference is the app's whole argument. One is a
/// model forming an opinion; the other is a database being read.
class AnalyzingOverlay extends StatelessWidget {
  const AnalyzingOverlay.photo({super.key})
      : title = 'Reading the photo',
        detail = 'This runs on the server and takes a few seconds.';

  const AnalyzingOverlay.barcode({super.key})
      : title = 'Looking up the barcode',
        detail = 'Checking the digits against Open Food Facts.';

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSubtle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppText.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(detail, style: AppText.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
