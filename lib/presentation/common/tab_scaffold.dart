import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// The common frame for the three list-and-settings tabs.
///
/// Shared so the three read as one app. Before this each tab built its own
/// header with its own spacing and its own idea of where the destructive
/// action went, which is the kind of drift nobody notices on one screen and
/// everybody notices flicking between three.
class TabScaffold extends StatelessWidget {
  const TabScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Sits beside the title rather than above it. A destructive action floating
  /// alone above a heading has nothing to be destructive *to* until the eye
  /// finds the list.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.display),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: action,
                ),
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A text button for a destructive action, sized to stay a secondary presence.
class DestructiveTextButton extends StatelessWidget {
  const DestructiveTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.negative,
        disabledForegroundColor: AppColors.inkMuted,
        // 44 keeps the tap target accessible even though the control is
        // visually small.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        textStyle: AppText.bodyStrong,
      ),
      child: Text(label),
    );
  }
}

/// Confirmation for an action that cannot be undone.
///
/// The buttons are labelled with what they do rather than with OK and Cancel,
/// and the title states the consequence. "Are you sure?" asks the user to
/// remember what they tapped; "Delete 12 scans?" tells them.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      title: Text(title, style: AppText.title),
      content: Text(message, style: AppText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            minimumSize: const Size(0, 44),
          ),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.negative,
            minimumSize: const Size(0, 44),
            textStyle: AppText.bodyStrong,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
