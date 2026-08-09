import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Covers the scan tab while the backend is thinking.
///
/// Opaque rather than a scrim: what it covers is the confirm view, and a
/// half-visible "Use this photo?" behind a spinner invites a tap on a button
/// that is no longer live.
class AnalyzingOverlay extends StatelessWidget {
  const AnalyzingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceSubtle,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text('Reading the photo', style: AppText.bodyStrong),
            SizedBox(height: AppSpacing.xs),
            // Names the wait and its cause. "Please wait" would say neither,
            // and this step is a network round trip that can genuinely take
            // several seconds.
            Text(
              'This runs on the server and takes a few seconds.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
