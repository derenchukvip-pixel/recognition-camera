import 'package:flutter/material.dart';

import '../design/buttons.dart';
import '../design/tokens.dart';

/// The consent gate's screen, with nothing platform-bound in it.
///
/// Separated from [TermsScreen] for the same reason [ProductReportView] is
/// separated from the scan flow: everything here is text and two callbacks, so
/// pulling out the parts that need `dart:io` and Hive lets the screen be
/// rendered in the web preview and reviewed without a device. The gate itself
/// — recording consent, and ending the session on refusal — stays where the
/// platform lives.
///
/// The content matters more than most consent screens' does. Every user sees
/// this, most see it first, and it is the only place to set the expectation
/// the rest of the app depends on: that answers are labelled by how far they
/// can be trusted, and that some of them are guesses. Said here, the badges on
/// the result screen confirm something already understood. Said only there,
/// they read as backpedalling.
class TermsContent extends StatelessWidget {
  const TermsContent({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Three specific limits rather than a paragraph of legal throat-clearing.
  /// A wall of small grey text is agreed to without being read, which is the
  /// same as not having one.
  static const List<_Limit> _limits = [
    _Limit(
      icon: Icons.auto_awesome_outlined,
      title: 'Most answers are inferences',
      body: 'A model reads the packaging and infers the rest. It can be '
          'wrong, and it can give a different answer to the same product on '
          'the next scan.',
    ),
    _Limit(
      icon: Icons.verified_outlined,
      title: 'Every claim says how far it can be trusted',
      body: 'Verified means it came from the barcode or a database that '
          'names its source, and repeats. Estimated means a guess. Unknown '
          'means nobody publishes it — and the app says so rather than '
          'filling it in.',
    ),
    _Limit(
      icon: Icons.gavel_outlined,
      title: 'Not advice, and not a compliance record',
      body: 'None of this is legally verified. Do not rely on it for '
          'sourcing decisions, certification, or legal advice.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSubtle,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                children: [
                  const Text('Before you start', style: AppText.display),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'This app makes claims about products. Three things to '
                    'know about how much they are worth.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final limit in _limits) ...[
                    _LimitCard(limit: limit),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Agreeing confirms you understand these limits and accept '
                    'the Terms of Use.',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: 'Agree and continue',
                    onPressed: onAccept,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Labelled with what it actually does. The camera is
                  // unreachable without consent, so declining ends the
                  // session — and a button called just "Decline" would hide
                  // that until it happened.
                  AppSecondaryButton(
                    label: 'Decline and close the app',
                    onPressed: onDecline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Limit {
  const _Limit({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.limit});

  final _Limit limit;

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.all(AppRadius.sm),
            ),
            child: Icon(limit.icon, size: 20, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(limit.title, style: AppText.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(limit.body, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
