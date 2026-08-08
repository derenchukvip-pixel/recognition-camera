import 'package:flutter/material.dart';

import '../../domain/models/product_report.dart';
import '../../domain/provenance.dart';
import '../design/provenance_badge.dart';
import '../design/tokens.dart';

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
  });

  final ProductReport report;
  final WidgetBuilder? imageBuilder;
  final VoidCallback? onClose;
  final VoidCallback? onSave;

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
              if (onSave != null)
                IconButton(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_border, color: AppColors.ink),
                  tooltip: 'Save',
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
                  _Headline(report: report),
                  const SizedBox(height: AppSpacing.lg),
                  _ClaimCard(
                    rows: [
                      _ClaimRow(
                        label: 'Brand registered in',
                        claim: report.registeredIn,
                      ),
                      _ClaimRow(
                        label: 'Manufactured in',
                        claim: report.manufacturedIn,
                      ),
                      _ClaimRow(
                        label: 'Headquarters',
                        claim: report.headquarters,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _MethodologyNote(),
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
  const _Headline({required this.report});

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
  const _ClaimCard({required this.rows});

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
  const _ClaimRow({required this.label, required this.claim});

  final String label;
  final ProvenanceClaim claim;

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
        ],
      ),
    );
  }
}

class _MethodologyNote extends StatelessWidget {
  const _MethodologyNote();

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
        ],
      ),
    );
  }
}
