import 'package:flutter/material.dart';

import 'domain/models/product_report.dart';
import 'domain/provenance.dart';
import 'presentation/design/tokens.dart';
import 'presentation/report/product_report_view.dart';

/// Web preview entry point.
///
/// The app itself cannot run on the web — `tflite_flutter`, `camera` and
/// `mobile_scanner` are all platform plugins with no web implementation. But
/// [ProductReportView] takes a plain [ProductReport] and nothing else, so the
/// result screen can be rendered anywhere, against fixtures.
///
/// That buys two things: the design can be reviewed and iterated without a
/// device in the loop, and the same build is a shareable link that shows the
/// interface to someone who is never going to install an APK.
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
      home: const _PreviewGallery(),
    );
  }
}

/// The three states the result screen has to handle well. Showing them side by
/// side is the point: a design that only looks good on the happy path is not
/// finished, and the "we don't know" case is the one this app has to get right.
class _PreviewGallery extends StatefulWidget {
  const _PreviewGallery();

  @override
  State<_PreviewGallery> createState() => _PreviewGalleryState();
}

class _PreviewGalleryState extends State<_PreviewGallery> {
  late int _index = _indexFromUrl();

  static final _fixtures = <String, ProductReport>{
    'Verified': _verified,
    'Partly known': _partlyKnown,
    'Unreadable': _unreadable,
  };

  /// `?fixture=unreadable` selects a state directly. Deep-linking each state
  /// means screenshots can be captured headlessly, and a link can point a
  /// reviewer at the exact case being discussed.
  static int _indexFromUrl() {
    final requested = Uri.base.queryParameters['fixture']?.toLowerCase();
    if (requested == null) return 0;
    final keys = _fixtures.keys.toList();
    final match = keys.indexWhere(
      (k) => k.toLowerCase().replaceAll(' ', '-') == requested,
    );
    return match >= 0 ? match : 0;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _fixtures.entries.toList();
    // `?bare=1` drops the fixture switcher so a capture contains only the
    // screen itself — the switcher is a review tool, not part of the product.
    final bare = Uri.base.queryParameters['bare'] == '1';
    return Scaffold(
      body: Column(
        children: [
          if (!bare) Material(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Text('Fixture', style: AppText.label),
                    const SizedBox(width: AppSpacing.md),
                    for (var i = 0; i < entries.length; i++) ...[
                      ChoiceChip(
                        label: Text(entries[i].key),
                        selected: _index == i,
                        onSelected: (_) => setState(() => _index = i),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              // Constrained to a handset width: this is a phone screen, and
              // reviewing it at 1400px wide would flatter a layout that has to
              // work at 390. In bare mode the viewport is already phone-sized,
              // so it fills it rather than leaving gutters in the capture.
              child: SizedBox(
                // 402 is the iPhone 16 logical width; capturing at exactly a
                // real handset size keeps the screenshots honest about how much
                // fits above the fold.
                width: bare ? 402 : 420,
                child: ProductReportView(
                  report: entries[_index].value,
                  onClose: () {},
                  onSave: () {},
                  // Drop a real photo at assets/preview/sample-product.jpg and
                  // it appears here. Deliberately no drawn stand-in: a fake
                  // photo frame next to real country claims is exactly the
                  // confusion this screen was rebuilt to remove.
                  imageBuilder: (_) => Image.asset(
                    'assets/preview/sample-product.jpg',
                    fit: BoxFit.cover,
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean scan: real barcode, valid checksum, brand known.
final _verified = ProductReport(
  barcode: '5702016616545',
  productName: const ProvenanceClaim(
    value: 'Recycling Truck 42107',
    provenance: Provenance.estimated,
    source: 'Image recognition',
  ),
  brand: const ProvenanceClaim(
    value: 'LEGO',
    provenance: Provenance.verified,
    source: 'GS1 registry',
  ),
  registeredIn: ProductReport.fromBarcode('5702016616545'),
  manufacturedIn: const ProvenanceClaim.unknown(
    caveat: 'LEGO does not publish per-item factory data. The company operates '
        'plants in Denmark, Hungary, Czechia, Mexico, China and Vietnam.',
  ),
  headquarters: const ProvenanceClaim(
    value: 'Denmark',
    provenance: Provenance.verified,
    source: 'Company filings',
  ),
);

/// A photo scan with no barcode: recognition only.
///
/// Note that the headquarters claim is `estimated` even though LEGO being
/// Danish is common knowledge. It is downgraded on purpose: it is derived from
/// a brand that was itself only recognised from a photo, and **a claim can
/// never be more certain than the claim it rests on**. If the model misread the
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
    caveat: 'No barcode was scanned. Scan the barcode on the box to get a '
        'reproducible answer instead of a guess.',
  ),
  manufacturedIn: const ProvenanceClaim.unknown(
    caveat: 'LEGO does not publish per-item factory data.',
  ),
  headquarters: const ProvenanceClaim(
    value: 'Denmark',
    provenance: Provenance.estimated,
    source: 'Derived from a brand that was itself only recognised from a photo',
  ),
);

/// A misread barcode. The checksum fails, so nothing earns a Verified badge —
/// this is the case that used to produce a confident wrong country.
final _unreadable = ProductReport(
  barcode: '4006381333932',
  productName: const ProvenanceClaim.unknown(),
  brand: const ProvenanceClaim.unknown(),
  registeredIn: ProductReport.fromBarcode('4006381333932'),
  manufacturedIn: const ProvenanceClaim.unknown(),
  headquarters: const ProvenanceClaim.unknown(),
);
