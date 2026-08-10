import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../design/tokens.dart';

/// Returns the scanned barcode to the caller, which does the lookup.
///
/// The screen knows nothing about GS1 or Open Food Facts on purpose: it reads
/// digits. Everything downstream of that — check digit, prefix, database —
/// belongs to the report, and keeping it out of here is what lets the report
/// be built and tested without a camera.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String? _barcode;

  /// The scanner keeps firing frames while the route animates out, so the
  /// first hit latches and the rest are ignored. Without it the same barcode
  /// pops the route several times over.
  bool _captured = false;

  void _onDetect(BarcodeCapture capture) {
    if (_captured) return;
    final value =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (value == null || value.isEmpty) return;

    setState(() {
      _captured = true;
      _barcode = value;
    });
    // The one unambiguous signal that the read happened, for a user who is
    // looking at the product rather than at the screen.
    unawaited(HapticFeedback.mediumImpact());

    // Resolved before the gap: by the time this fires the user may have hit
    // back and this State would be gone.
    final navigator = Navigator.of(context);
    // Long enough to see which digits were read — a scanner that closes the
    // instant it fires leaves the user unsure whether it read the product or
    // the shelf label next to it — and short enough not to feel stuck.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      navigator.pop(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect, fit: BoxFit.cover),
          const _ScannerReticle(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.topLeft,
                child: _ScannerBackButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _ScannerStatus(barcode: _barcode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A cut-out with a bright frame, sized to a retail barcode rather than to a
/// square. Aiming is the whole interaction, and a square reticle over a wide
/// barcode teaches the wrong distance to stand at.
class _ScannerReticle extends StatelessWidget {
  const _ScannerReticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.78,
          child: AspectRatio(
            aspectRatio: 5 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: AppRadius.cardRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerStatus extends StatelessWidget {
  const _ScannerStatus({this.barcode});

  final String? barcode;

  @override
  Widget build(BuildContext context) {
    final captured = barcode != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            captured ? 'BARCODE READ' : 'LINE UP THE BARCODE',
            style: AppText.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            captured ? barcode! : 'Hold steady until the digits appear here.',
            textAlign: TextAlign.center,
            style: captured
                ? AppText.title.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 1.5,
                  )
                : AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _ScannerBackButton extends StatelessWidget {
  const _ScannerBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close the scanner',
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
