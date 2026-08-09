import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The app's four destinations.
///
/// Labelled, which the previous version was not. Four unlabelled glyphs on a
/// solid blue bar asked the user to learn an icon language for a screen they
/// visit twice a week — and one of those glyphs was a brightness icon
/// standing in for "preferences", which no amount of familiarity would fix.
class DetectionNavBar extends StatelessWidget {
  const DetectionNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_Destination> _destinations = [
    _Destination(
      label: 'Scan',
      icon: Icons.photo_camera_outlined,
      selectedIcon: Icons.photo_camera,
    ),
    _Destination(
      label: 'Saved',
      icon: Icons.bookmark_border,
      selectedIcon: Icons.bookmark,
    ),
    _Destination(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
    _Destination(
      label: 'Preferences',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;

  /// The filled variant. Weight is the second signal after colour, so the
  /// selected tab stays identifiable in greyscale.
  final IconData selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.badge.copyWith(
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
