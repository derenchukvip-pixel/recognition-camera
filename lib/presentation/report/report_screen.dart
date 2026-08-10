import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/product_report.dart';
import '../../domain/origin_match.dart';
import '../preferences/origin_preferences_view_model.dart';
import 'product_report_view.dart';
import 'share_card.dart';

/// The result screen as the app uses it: the pure [ProductReportView] plus the
/// three things it deliberately does not know about — the user's preferences,
/// the file system, and the share sheet.
///
/// One widget for all four entry points (photo scan, barcode scan, history,
/// saved) so those capabilities cannot drift apart between them, which is how
/// the live scan ended up on a different screen from history in the first
/// place.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.report,
    this.imageBuilder,
    this.onSave,
    this.isSaved = false,
  });

  final ProductReport report;
  final WidgetBuilder? imageBuilder;
  final VoidCallback? onSave;
  final bool isSaved;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final GlobalKey _shareKey = GlobalKey();

  /// The share card is only mounted while a share is being prepared. It is
  /// 1080 logical pixels wide and lays out a second copy of the whole result,
  /// which is not worth doing on every frame of a screen nobody is sharing.
  bool _preparingShare = false;

  Future<void> _share() async {
    if (_preparingShare) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _preparingShare = true);
    try {
      // One frame for the offscreen card to lay out and paint. Without it the
      // boundary has nothing to hand back and `toImage` throws.
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await _renderShareCard();
      if (bytes == null) throw StateError('nothing was rendered');

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/scan-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          // The badges are in the image; this is for the places that show a
          // caption and not much else.
          text: _shareText(widget.report),
        ),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Share failed: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create the image to share.')),
      );
    } finally {
      if (mounted) setState(() => _preparingShare = false);
    }
  }

  Future<Uint8List?> _renderShareCard() async {
    final boundary =
        _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // pixelRatio 1: the card is already authored at 1080 wide, so the output
    // is the same size on every device rather than scaling with the phone.
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<OriginPreferencesViewModel>();

    final view = ProductReportView(
      report: widget.report,
      imageBuilder: widget.imageBuilder,
      // Every entry point pushes this as a route, so closing is always a pop.
      // Kept as an explicit button as well as a back gesture: the result is a
      // full-screen page and the way out should be visible on it.
      onClose: () => Navigator.of(context).maybePop(),
      onSave: widget.onSave,
      isSaved: widget.isSaved,
      onShare: _preparingShare ? null : _share,
      originMatcher: (claim) => matchOrigin(
        claim.value,
        preferred: preferences.aligned,
        avoided: preferences.lessAligned,
      ),
    );

    if (!_preparingShare) return view;

    return Stack(
      children: [
        view,
        // Painted, but off the left edge. `Offstage` would be the obvious
        // choice and is the wrong one: it skips painting entirely, so the
        // boundary has no layer to capture.
        Positioned(
          left: -ShareCard.width - 100,
          top: 0,
          child: RepaintBoundary(
            key: _shareKey,
            child: MediaQuery(
              // Fixed text scale, so a user's accessibility setting changes
              // their screen and not the image they send to someone else.
              data: const MediaQueryData(textScaler: TextScaler.noScaling),
              child: Material(
                color: Colors.transparent,
                child: ShareCard(report: widget.report),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The caption that travels beside the image.
///
/// Says what the strongest claim is worth rather than asserting the product's
/// origin, because a caption is what gets quoted when the image does not load.
String _shareText(ProductReport report) {
  final name = report.productName.hasValue
      ? report.productName.displayValue
      : 'An unidentified product';
  final basis = report.hasVerifiedClaim
      ? 'Some of this is read from the barcode and repeats; the rest is '
          'estimated or unknown.'
      : 'Everything here is an estimate or unknown — nothing was verified.';
  return '$name — scanned. $basis';
}
