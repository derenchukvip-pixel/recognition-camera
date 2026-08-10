import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/consent/disclaimer_storage.dart';
import '../design/buttons.dart';
import '../design/tokens.dart';
import '../detection/detection_screen.dart';

/// The consent gate, shown once before the camera is reachable.
///
/// Every user sees this screen and most of them see it first, which makes it
/// the only place to set the expectation the whole app depends on: that its
/// answers are labelled by how much they can be trusted, and that some of them
/// are guesses. Said here, the badges on the result screen confirm something
/// already understood. Said only there, they read as backpedalling.
///
/// So the disclaimer is written as three specific limits rather than as a
/// paragraph of legal throat-clearing. A wall of small grey text is agreed to
/// without being read, which is the same as not having one.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static final DisclaimerStorage _disclaimerStorage = DisclaimerStorage();

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

  Future<void> _decline() async {
    await _disclaimerStorage.setAccepted(false);
    if (Platform.isIOS) {
      Future.delayed(const Duration(milliseconds: 80), () => exit(0));
    }
    SystemNavigator.pop();
  }

  Future<void> _accept(BuildContext context) async {
    await _disclaimerStorage.setAccepted(true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DetectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
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
                    onPressed: () => _accept(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Labelled with what it actually does. The camera is
                  // unreachable without consent, so declining ends the
                  // session — and a button called just "Decline" would hide
                  // that until it happened.
                  AppSecondaryButton(
                    label: 'Decline and close the app',
                    onPressed: _decline,
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
