import 'package:flutter/material.dart';

import 'domain/models/product_report.dart';
import 'domain/models/report_from_barcode.dart';
import 'domain/origin_match.dart';
import 'domain/provenance.dart';
import 'presentation/common/scan_list_card.dart';
import 'presentation/common/tab_scaffold.dart';
import 'presentation/design/empty_state.dart';
import 'presentation/design/tokens.dart';
import 'presentation/detection/detection_view_model.dart';
import 'presentation/detection/widgets/confirm_photo_view.dart';
import 'presentation/detection/widgets/detection_nav_bar.dart';
import 'presentation/detection/widgets/scan_home_view.dart';
import 'presentation/report/product_report_view.dart';
import 'presentation/report/share_card.dart';
import 'presentation/terms/terms_content.dart';

/// Web preview entry point.
///
/// The app itself cannot run on the web — `tflite_flutter`, `camera` and
/// `mobile_scanner` are platform plugins with no web implementation, and the
/// stored records live in Hive. But the screens were built to take plain data
/// and callbacks and reach for nothing else, so each one renders here against
/// fixtures.
///
/// That is not a trick for the demo; it is what the separation is for. The
/// design can be reviewed and iterated without a device in the loop, the
/// screenshots in the README are captured headlessly from this build, and the
/// same build is a link that shows the interface to someone who is never going
/// to install an APK.
///
///   flutter run -d chrome -t lib/main_preview.dart
///   flutter build web -t lib/main_preview.dart
void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recognition Camera — UI preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceSubtle,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand),
        fontFamily: 'Roboto',
      ),
      home: const PreviewGallery(),
    );
  }
}

/// One entry in the switcher.
class _Screen {
  const _Screen({required this.slug, required this.label, required this.build});

  final String slug;
  final String label;
  final WidgetBuilder build;
}

class PreviewGallery extends StatefulWidget {
  const PreviewGallery({super.key});

  @override
  State<PreviewGallery> createState() => _PreviewGalleryState();
}

class _PreviewGalleryState extends State<PreviewGallery> {
  static final List<_Screen> _screens = [
    _Screen(slug: 'scan', label: 'Scan', build: (_) => const _ScanPreview()),
    _Screen(
      slug: 'confirm',
      label: 'Frame check',
      build: (_) => const _ConfirmPreview(),
    ),
    _Screen(
      slug: 'verified',
      label: 'Barcode result',
      build: (_) => _report(_verified),
    ),
    _Screen(
      slug: 'photo-scan',
      label: 'Photo result',
      build: (_) => _report(_partlyKnown, withPhoto: true),
    ),
    _Screen(
      slug: 'unreadable',
      label: 'Unreadable',
      build: (_) => _report(_unreadable),
    ),
    _Screen(
      slug: 'share',
      label: 'Shared image',
      build: (_) => const _SharePreview(),
    ),
    _Screen(
      slug: 'history',
      label: 'History',
      build: (_) => const _HistoryPreview(),
    ),
    _Screen(slug: 'empty', label: 'Empty', build: (_) => const _EmptyPreview()),
    _Screen(
      slug: 'consent',
      label: 'Consent',
      build: (_) => TermsContent(onAccept: () {}, onDecline: () {}),
    ),
  ];

  late int _index = _indexFromUrl();

  /// `?screen=history` selects one directly, so a screenshot can be captured
  /// headlessly and a link can point a reviewer at the exact screen being
  /// discussed. `?fixture=` is the older spelling and still resolves, because
  /// it is in the README and in links already sent.
  static int _indexFromUrl() {
    final params = Uri.base.queryParameters;
    final requested = (params['screen'] ?? params['fixture'])?.toLowerCase();
    if (requested == null) return 0;
    final match = _screens.indexWhere((s) => s.slug == requested);
    return match >= 0 ? match : 0;
  }

  @override
  Widget build(BuildContext context) {
    // `?bare=1` drops the switcher so a capture contains only the screen
    // itself — the switcher is a review tool, not part of the product.
    final bare = Uri.base.queryParameters['bare'] == '1';

    return Scaffold(
      body: Column(
        children: [
          if (!bare) _Switcher(
            screens: _screens,
            index: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
          Expanded(
            child: Center(
              // Constrained to a handset width: this is a phone screen, and
              // reviewing it at 1400px would flatter a layout that has to work
              // at 402 — the iPhone 16 logical width.
              child: SizedBox(
                width: bare ? 402 : 420,
                child: _PhoneFrame(child: _screens[_index].build(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Switcher extends StatelessWidget {
  const _Switcher({
    required this.screens,
    required this.index,
    required this.onChanged,
  });

  final List<_Screen> screens;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Text('Screen', style: AppText.label),
                const SizedBox(width: AppSpacing.md),
                for (var i = 0; i < screens.length; i++) ...[
                  ChoiceChip(
                    label: Text(screens[i].label),
                    selected: index == i,
                    onSelected: (_) => onChanged(i),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips the screen to a handset shape so the captures look like a phone
/// rather than a narrow web page.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: ColoredBox(color: AppColors.surfaceSubtle, child: child),
    );
  }
}

/// Stands in for the user's own lists. Denmark is on the preferred one, so
/// the barcode fixture shows a preference mark and a reviewer can see how it
/// differs from a provenance badge — which is the entire design problem.
OriginMatch _previewMatch(ProvenanceClaim claim) => matchOrigin(
      claim.value,
      preferred: const ['Denmark'],
      avoided: const ['China'],
    );

Widget _report(ProductReport report, {bool withPhoto = false}) {
  return ProductReportView(
    report: report,
    onClose: () {},
    onSave: () {},
    onShare: () {},
    originMatcher: _previewMatch,
    imageBuilder: withPhoto
        ? (_) => Image.asset(
              'assets/preview/sample-product.jpg',
              fit: BoxFit.cover,
              // Deliberately no drawn stand-in: a fake photo frame next to
              // real country claims is exactly the confusion this screen was
              // rebuilt to remove.
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.surfaceSubtle,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Add assets/preview/sample-product.jpg\n'
                      'to preview the photo-scan layout',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
                  ),
                ),
              ),
            )
        : null,
  );
}

/// The scan tab, with the mode switch live so a reviewer can see both states.
class _ScanPreview extends StatefulWidget {
  const _ScanPreview();

  @override
  State<_ScanPreview> createState() => _ScanPreviewState();
}

class _ScanPreviewState extends State<_ScanPreview> {
  ScanMode _mode = ScanMode.photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: ScanHomeView(
          mode: _mode,
          onModeChanged: (mode) => setState(() => _mode = mode),
          onOpenCamera: () {},
          onPickFromGallery: () {},
          onScanBarcode: () {},
        ),
      ),
      bottomNavigationBar: DetectionNavBar(currentIndex: 0, onTap: (_) {}),
    );
  }
}

/// The step between the shutter and the upload.
///
/// Shown here because it is the only screen where the on-device model speaks,
/// and because the sentence under the result is the one that keeps an object
/// category from being read as an identification.
class _ConfirmPreview extends StatelessWidget {
  const _ConfirmPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: ConfirmPhotoView(
        imageBuilder: (_) => Image.asset(
          'assets/preview/sample-product.jpg',
          fit: BoxFit.cover,
        ),
        onConfirm: () {},
        onRetake: () {},
        frameCheck: FrameCheck.found,
        // What YOLOv8n actually returns for this photograph's class of
        // object. A category, which is all it has.
        frameSummary: 'Potted plant in frame',
      ),
    );
  }
}

/// What actually gets sent when the result is shared.
///
/// Scaled down to fit the phone frame; the real thing is 1080 wide. Shown in
/// the gallery because the point of the card is what it carries — the badge
/// legend, in the same image — and that is only checkable by looking at it.
class _SharePreview extends StatelessWidget {
  const _SharePreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: SingleChildScrollView(
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: ShareCard(report: _verified),
          ),
        ),
      ),
    );
  }
}

/// The history list.
///
/// Two rows, chosen to sit next to each other: a barcode scan carrying a
/// Verified badge and a photo scan carrying an Estimated one. Reading the
/// difference without opening either row is the reason the badge is in the
/// list at all.
class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: TabScaffold(
          title: 'History',
          subtitle: 'Every scan, and how much of it was verified',
          action: DestructiveTextButton(label: 'Clear', onPressed: () {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              // No thumbnail: a barcode scan never had a photo, and the card
              // shows the mark of what it does have rather than a broken one.
              ScanListCard(report: _verified, onTap: () {}),
              const SizedBox(height: AppSpacing.sm),
              ScanListCard(
                report: _partlyKnown,
                thumbnailBuilder: (_) => Image.asset(
                  'assets/preview/sample-product.jpg',
                  fit: BoxFit.cover,
                ),
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              ScanListCard(report: _unreadable, onTap: () {}),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DetectionNavBar(currentIndex: 2, onTap: (_) {}),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: TabScaffold(
          title: 'Saved',
          subtitle: 'Scans you chose to keep',
          child: EmptyState(
            icon: Icons.bookmark_border,
            title: 'Nothing saved yet',
            message: 'Tap the bookmark on a scan result to keep it here. '
                'Saved scans stay on this device.',
            actionLabel: 'Scan a product',
            onAction: () {},
          ),
        ),
      ),
      bottomNavigationBar: DetectionNavBar(currentIndex: 1, onTap: (_) {}),
    );
  }
}

/// A clean barcode scan: valid check digit, product found in the database.
final _verified = reportFromBarcode(
  '5702016616545',
  openFoodFactsProduct: const {
    'product_name': 'Recycling Truck 42107',
    'brands': 'LEGO',
  },
);

/// A photo scan with no barcode: recognition only.
///
/// Note that the headquarters claim is Estimated even though LEGO being Danish
/// is common knowledge. It is downgraded on purpose: it is derived from a
/// brand that was itself only recognised from a photo, and **a claim can never
/// be more certain than the claim it rests on**. If the model misread the
/// logo, the country is wrong too, and a Verified badge there would be
/// laundering a guess into a fact.
final _partlyKnown = ProductReport(
  imagePath: 'assets/preview/sample-product.jpg',
  productName: const ProvenanceClaim(
    value: 'Bonsai Tree 10281',
    provenance: Provenance.estimated,
    source: 'Image recognition',
  ),
  brand: const ProvenanceClaim(
    value: 'LEGO',
    provenance: Provenance.estimated,
    source: 'Image recognition',
  ),
  registeredIn: const ProvenanceClaim.unknown(
    caveat: 'No barcode was scanned. Scan the barcode on the packaging to get '
        'a reproducible answer instead of a guess.',
  ),
  manufacturedIn: const ProvenanceClaim.unknown(
    caveat: 'LEGO does not publish per-item factory data.',
  ),
  headquarters: const ProvenanceClaim(
    value: 'Denmark',
    provenance: Provenance.estimated,
    source: 'Derived from a brand that was itself only recognised from a photo',
  ),
  taxJurisdiction: const ProvenanceClaim(
    value: 'Denmark',
    provenance: Provenance.estimated,
    source: 'Derived from a brand that was itself only recognised from a photo',
  ),
);

/// A misread barcode. The check digit fails, so nothing earns a Verified badge
/// — this is the case that used to produce a confident, wrong country.
final _unreadable = reportFromBarcode('4006381333932');
