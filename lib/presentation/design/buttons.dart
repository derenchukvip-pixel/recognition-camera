import 'package:flutter/material.dart';

import 'tokens.dart';

/// The primary action on a screen. There is one.
///
/// Height and radius are fixed rather than parameterised: a screen with two
/// differently-shaped primary buttons has no primary button. 48 clears the
/// 44pt accessible minimum with room for the label to breathe.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkMuted,
          elevation: 0,
          textStyle: AppText.bodyStrong,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
          ),
        ),
        child: _Label(label: label, icon: icon),
      ),
    );
  }
}

/// The alternative to the primary action. Outlined, never a second fill —
/// two filled buttons side by side make the user read both before choosing.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          disabledForegroundColor: AppColors.inkMuted,
          textStyle: AppText.bodyStrong,
          side: const BorderSide(color: AppColors.brand),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
          ),
        ),
        child: _Label(label: label, icon: icon),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
