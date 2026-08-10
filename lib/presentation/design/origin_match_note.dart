import 'package:flutter/material.dart';

import '../../domain/origin_match.dart';
import 'tokens.dart';

/// Marks a claim whose country is on one of the user's lists.
///
/// Everything about how this looks is chosen to keep it from being read as a
/// verification, because that is the failure mode. An earlier build put a
/// green `Icons.verified` tick beside a country that matched a preference —
/// the same tick, in the same green, as the badge that means "this is a
/// reproducible fact". A user glancing at the screen had no way to tell the
/// app had confirmed something from the app having merely compared two strings
/// they typed themselves.
///
/// So: **brand blue, never the semantic palette.** Green, amber and slate are
/// spoken for — they mean Verified, Estimated and Unknown, and they get to
/// mean nothing else. Blue here reads as "this is about your settings".
///
/// **A strip, not a pill.** Provenance badges are pills. This is the same
/// shape as the caveat block it sits beside, which is the right weight: a
/// note attached to a claim, not a verdict on it.
///
/// **And it says what it is.** One line naming the list, one line saying the
/// match is against preferences rather than about the country being correct.
class OriginMatchNote extends StatelessWidget {
  const OriginMatchNote({super.key, required this.match});

  final OriginMatch match;

  @override
  Widget build(BuildContext context) {
    if (match == OriginMatch.none) return const SizedBox.shrink();

    final (IconData icon, String label) = switch (match) {
      OriginMatch.preferred => (
          Icons.push_pin_outlined,
          'On your preferred list',
        ),
      OriginMatch.avoided => (
          Icons.flag_outlined,
          'On your avoid list',
        ),
      // Both, and both get said. Reporting only one would answer half the
      // question on a claim naming several countries.
      OriginMatch.mixed => (
          Icons.swap_horiz,
          'On both of your lists',
        ),
      OriginMatch.none => (Icons.circle, ''),
    };

    return Semantics(
      label: '$label. A match against your preferences, not a verification.',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: const BorderRadius.all(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.caption.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Matched against your preferences. Says nothing about '
                      'whether the country above is correct.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
