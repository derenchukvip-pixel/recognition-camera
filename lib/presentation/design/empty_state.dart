import 'package:flutter/material.dart';

import 'buttons.dart';
import 'tokens.dart';

/// A screen with no data yet.
///
/// Designed rather than defaulted. This is the first thing a new user sees on
/// two of the four tabs, and "No data" tells them neither what the screen is
/// for nor how to fill it. Three parts, always: a mark, one line saying what
/// this place holds, one line saying how something gets here.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              // Wrapped short. A single line running the full width of a
              // phone reads as a paragraph and gets skipped.
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
