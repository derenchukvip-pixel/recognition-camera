import 'package:flutter/material.dart';

import '../../domain/models/product_report.dart';
import '../../domain/origin_match.dart';
import '../../domain/provenance.dart';
import '../design/origin_match_note.dart';
import '../design/provenance_badge.dart';
import '../design/tokens.dart';

/// The product name and its badge.
const Key reportHeadlineKey = Key('report-headline');

/// The card of `label → value → badge` rows.
const Key reportClaimsKey = Key('report-claims');

/// The "how to read this" block, which names every badge by definition and so
/// contains all three words regardless of what this particular scan found.
const Key provenanceLegendKey = Key('provenance-legend');

/// The result screen.
///
/// Pure: it takes a [ProductReport] and an optional image builder, and reaches
/// for nothing else. The phone passes a builder that renders a `File`; the web
/// preview passes one that renders an asset. Neither knows about the other.
class ProductReportView extends StatelessWidget {
  const ProductReportView({
    super.key,
    required this.report,
    this.imageBuilder,
    this.onClose,
    this.onSave,
    this.isSaved = false,
    this.onShare,
    this.originMatcher,
  });

  final ProductReport report;
  final WidgetBuilder? imageBuilder;
  final VoidCallback? onClose;

  /// Null hides the action entirely rather than disabling it. A barcode scan
  /// has nowhere to be saved to without losing its provenance — the stored
  /// record predates the badges and cannot hold them — and a greyed-out
  /// bookmark would advertise a feature that is not coming back on.
  final VoidCallback? onSave;

  final bool isSaved;

  /// Renders the result as an image and hands it to the system share sheet.
  /// Null while one is already being prepared, which disables the button
  /// without removing it.
  final VoidCallback? onShare;

  /// Resolves a country claim against the user's own lists.
  ///
  /// A callback rather than a view model, so this widget keeps taking a
  /// [ProductReport] and nothing else — the web preview passes a fixture
  /// matcher, the app passes one reading live preferences, and neither knows
  /// about the other. Null switches the feature off, which is what the
  /// shared image does: the recipient's copy must not carry the sender's
  /// settings.
  final OriginMatch Function(ProvenanceClaim claim)? originMatcher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            leading: onClose == null
                ? null
                : IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: AppColors.ink),
                    tooltip: 'Close',
                  ),
            actions: [
              if (onShare != null)
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share, color: AppColors.ink),
                  tooltip: 'Share',
                ),
              if (onSave != null)
                IconButton(
                  onPressed: onSave,
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? AppColors.brand : AppColors.ink,
                  ),
                  // Filled vs outlined already carries the state; the label
                  // says which way the tap goes, because an icon that means
                  // "saved" and an icon that means "save it" look the same to
                  // a screen reader otherwise.
                  tooltip: isSaved ? 'Remove from saved' : 'Save',
                ),
            ],
            title: const Text('Scan result', style: AppText.bodyStrong),
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photo only when a photo actually exists. A barcode scan
                  // gets a barcode header instead of an empty picture frame,
                  // because the reading came from the digits, not from a
                  // camera.
                  if (report.source == ScanSource.photo && imageBuilder != null)
                    _ImageCard(builder: imageBuilder!)
                  else if (report.source == ScanSource.barcode)
                    _BarcodeHeader(barcode: report.barcode!),
                  const SizedBox(height: AppSpacing.lg),
                  // The three regions are keyed because a badge means
                  // something different in each of them: in the headline and
                  // the claim card it is an assertion about this product, in
                  // the legend below it is a definition. A test that searches
                  // the whole screen for "VERIFIED" cannot tell the two apart,
                  // and the legend would mask exactly the regression the tests
                  // exist to catch.
                  _Headline(key: reportHeadlineKey, report: report),
                  const SizedBox(height: AppSpacing.lg),
                  _ClaimCard(
                    key: reportClaimsKey,
                    rows: [
                      _ClaimRow(
                        label: 'Brand registered in',
                        claim: report.registeredIn,
                        matcher: originMatcher,
                      ),
                      _ClaimRow(
                        label: 'Manufactured in',
                        claim: report.manufacturedIn,
                        matcher: originMatcher,
                      ),
                      _ClaimRow(
                        label: 'Headquarters',
                        claim: report.headquarters,
                        matcher: originMatcher,
                      ),
                      // Only when the reading actually covered it. A barcode
                      // lookup says nothing about tax residency, and an
                      // Unknown badge on a question that was never asked
                      // reads as "we checked" — see
                      // ProductReport.taxJurisdiction.
                      if (report.taxJurisdiction != null)
                        _ClaimRow(
                          label: 'Profit booked in',
                          claim: report.taxJurisdiction!,
                          matcher: originMatcher,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MethodologyNote(
                    key: provenanceLegendKey,
                    originMatcher: originMatcher,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: AppColors.border,
          child: builder(context),
        ),
      ),
    );
  }
}

/// Shown instead of a photo when the scan was a barcode.
///
/// It renders the digits large and monospaced, because on this screen the
/// barcode *is* the evidence — every Verified badge below traces back to it.
class _BarcodeHeader extends StatelessWidget {
  const _BarcodeHeader({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.all(AppRadius.sm),
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 26,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCANNED BARCODE', style: AppText.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  barcode,
                  style: AppText.title.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'No photo was taken — every reading below comes from these '
                  'digits.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({super.key, required this.report});

  final ProductReport report;

  @override
  Widget build(BuildContext context) {
    final name = report.productName;
    final brand = report.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name.hasValue ? name.displayValue : 'Product not identified',
                style: AppText.display,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ProvenanceBadge(name.provenance),
          ],
        ),
        if (brand.hasValue) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('by ${brand.displayValue}', style: AppText.caption),
        ],
        // Only when a photo is also present — otherwise the barcode already
        // has the header above and repeating it here is noise.
        if (report.barcode != null && report.source == ScanSource.photo) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            report.barcode!,
            style: AppText.caption.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({super.key, required this.rows});

  final List<_ClaimRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({
    required this.label,
    required this.claim,
    this.matcher,
  });

  final String label;
  final ProvenanceClaim claim;
  final OriginMatch Function(ProvenanceClaim claim)? matcher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label.toUpperCase(), style: AppText.label)),
              ProvenanceBadge(claim.provenance, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            claim.displayValue,
            style: claim.hasValue
                ? AppText.bodyStrong
                : AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          if (claim.source != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.link, size: 13, color: AppColors.inkMuted),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Expanded, not bare: attribution can be a full sentence
                // ("derived from a brand that was itself only recognised
                // from a photo") and must wrap rather than run off the card.
                Expanded(
                  child: Text(claim.source!, style: AppText.caption),
                ),
              ],
            ),
          ],
          if (claim.caveat != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.all(AppRadius.sm),
              ),
              child: Text(claim.caveat!, style: AppText.caption),
            ),
          ],
          if (matcher != null) OriginMatchNote(match: matcher!(claim)),
        ],
      ),
    );
  }
}

class _MethodologyNote extends StatelessWidget {
  const _MethodologyNote({super.key, this.originMatcher});

  /// Only to decide whether the preference paragraph belongs here at all.
  final Object? originMatcher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW TO READ THIS', style: AppText.label),
          const SizedBox(height: AppSpacing.md),
          for (final p in Provenance.values) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProvenanceBadge(p, compact: true),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(p.explanation, style: AppText.caption)),
              ],
            ),
            if (p != Provenance.values.last)
              const SizedBox(height: AppSpacing.sm),
          ],
          // Said here as well as on each marked row, because the two kinds of
          // annotation on this screen answer different questions and the one
          // that is easiest to misread is the preference mark.
          if (originMatcher != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.push_pin_outlined,
                  size: 16,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'A pin or a flag means the country is on one of your own '
                    'lists in Preferences. That is a match against your '
                    'settings, decided separately from the badges above and '
                    'never a check of whether the country is right.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
