import 'package:flutter/material.dart';

/// Design tokens for the app.
///
/// Everything visual resolves to a value here rather than to a literal at a
/// call site, so a colour or a spacing step can be changed once instead of
/// grepped for. The provenance colours in particular are semantic, not
/// decorative — they are the only thing separating a fact from a guess on
/// screen, so they are defined next to each other where the contrast between
/// them is easy to judge.
class AppColors {
  const AppColors._();

  // Brand
  static const Color ink = Color(0xFF0B1B2B);
  static const Color inkMuted = Color(0xFF5A6B7D);
  static const Color brand = Color(0xFF052F61);
  static const Color brandBright = Color(0xFF1565C0);

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF4F7FA);
  static const Color border = Color(0xFFE2E8F0);

  // Provenance — semantic, never reused for decoration.
  static const Color verified = Color(0xFF0E7A5F);
  static const Color verifiedSurface = Color(0xFFE6F4EF);
  static const Color estimated = Color(0xFF9A5B00);
  static const Color estimatedSurface = Color(0xFFFDF1E0);
  static const Color unknown = Color(0xFF64748B);
  static const Color unknownSurface = Color(0xFFF1F5F9);

  /// Failure. Kept apart from the provenance colours above even though the
  /// hues are neighbours: those three say how much a claim can be trusted,
  /// this one says an operation did not complete. Reusing `estimated` orange
  /// for a network error would make a badge that means "this might be wrong"
  /// also mean "something broke", and the badge is the one thing on screen
  /// that has to keep meaning exactly one thing.
  static const Color negative = Color(0xFFB11C1C);
  static const Color negativeSurface = Color(0xFFFDECEC);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  const AppRadius._();

  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(22);

  static const BorderRadius cardRadius = BorderRadius.all(md);
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(999));
}

/// The one elevation in the app.
///
/// Deliberately singular. A second shadow would have to mean a second level of
/// "raised", and nothing here is two levels above the page — a mix of blur
/// radii across a small app reads as inattention, not depth. Applied only to
/// things that genuinely float over their surroundings: the selected segment
/// of a control, and nothing else so far.
class AppShadow {
  const AppShadow._();

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x0F0B1B2B),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x140B1B2B),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

/// Durations, so that every transition in the app is one of three speeds
/// rather than whatever felt right at the call site.
///
/// Nothing exceeds 300ms: past that, an animation stops explaining where
/// something came from and starts making the app feel slow. Callers are
/// expected to collapse these to [Duration.zero] when
/// `MediaQuery.disableAnimationsOf` is true.
class AppMotion {
  const AppMotion._();

  /// Presses, checkboxes — feedback that must feel instant.
  static const Duration micro = Duration(milliseconds: 120);

  /// A card appearing, a state changing in place.
  static const Duration state = Duration(milliseconds: 200);

  /// A whole screen replacing another.
  static const Duration screen = Duration(milliseconds: 280);
}

class AppText {
  const AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  /// Field labels. Uppercase tracking is what lets a label sit directly above
  /// its value without a divider and still read as a label.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.inkMuted,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.inkMuted,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}
