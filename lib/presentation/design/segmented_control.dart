import 'package:flutter/material.dart';

import 'tokens.dart';

/// One option in an [AppSegmentedControl].
class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;

  /// One word where possible. A segmented control is read at a glance and
  /// sized by its longest label, so a two-word segment makes every other
  /// segment wider for nothing.
  final String label;

  /// Not decoration. The icon is what makes the two modes distinguishable in
  /// the half-second before anyone reads the labels, and it is the second
  /// carrier of "which one is selected" for a user who cannot rely on the
  /// colour shift alone.
  final IconData icon;
}

/// A two-or-three-way mode switch.
///
/// Used for choosing how to scan. That choice deserves a control that shows
/// both options at once rather than a pair of buttons: the modes are mutually
/// exclusive alternatives with different guarantees — a barcode is
/// reproducible, a photo is a guess — and a user who never sees the other
/// option never learns the better one exists. Two `ElevatedButton.icon`s side
/// by side, which is what this replaces, say "two actions", not "pick one".
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // 200ms is the design system's state-change step. Zero when the user has
    // asked the OS to reduce motion — a sliding selection is decoration, and
    // decoration is the first thing that setting is meant to switch off.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.state;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment<T>(
                option: option,
                selected: option.value == value,
                duration: duration,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.brand : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.pillRadius,
          child: InkWell(
            onTap: selected ? null : onTap,
            borderRadius: AppRadius.pillRadius,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeInOut,
              // 44 is the accessible minimum touch target, and the control is
              // sized to it rather than to the text.
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: AppRadius.pillRadius,
                boxShadow: selected ? AppShadow.raised : const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(option.icon, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    option.label,
                    style: (selected ? AppText.bodyStrong : AppText.body)
                        .copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
