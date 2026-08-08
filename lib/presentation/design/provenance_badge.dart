import 'package:flutter/material.dart';

import '../../domain/provenance.dart';
import 'tokens.dart';

/// The badge that separates a fact from a guess.
///
/// Deliberately not a bare colour dot: colour alone fails for the ~8% of men
/// with red-green colour blindness, and this is the one element on the screen
/// that must not be ambiguous. Icon, word, and colour all carry the same
/// meaning, so any one of them is enough.
class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge(this.provenance, {super.key, this.compact = false});

  final Provenance provenance;
  final bool compact;

  Color get _fg => switch (provenance) {
        Provenance.verified => AppColors.verified,
        Provenance.estimated => AppColors.estimated,
        Provenance.unknown => AppColors.unknown,
      };

  Color get _bg => switch (provenance) {
        Provenance.verified => AppColors.verifiedSurface,
        Provenance.estimated => AppColors.estimatedSurface,
        Provenance.unknown => AppColors.unknownSurface,
      };

  IconData get _icon => switch (provenance) {
        Provenance.verified => Icons.verified_outlined,
        Provenance.estimated => Icons.auto_awesome_outlined,
        Provenance.unknown => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${provenance.label}. ${provenance.explanation}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: compact ? 12 : 14, color: _fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              provenance.label.toUpperCase(),
              style: AppText.badge.copyWith(color: _fg),
            ),
          ],
        ),
      ),
    );
  }
}
