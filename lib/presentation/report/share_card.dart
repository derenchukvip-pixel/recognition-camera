import 'package:flutter/material.dart';

import '../../domain/models/product_report.dart';
import '../../domain/provenance.dart';
import '../design/provenance_badge.dart';
import '../design/tokens.dart';

/// The scan result as a single image, for sending to someone.
///
/// The legend is not decoration and is not optional. The whole reason this
/// exists as a purpose-built card rather than a screenshot of the screen is
/// that a screenshot loses whatever scrolled off — and what scrolls off first
/// is "how to read this". A picture of a country name under a green tick,
/// arriving in a chat with no explanation, is exactly the claim this app was
/// rebuilt to stop making: *the app said Denmark*.
///
/// So the badges travel with their definitions, in the same image, always.
/// Everything else on the card is negotiable; that is not.
///
/// Two things are deliberately absent. **The photo**, because the sender's
/// snapshot of their kitchen counter is not evidence and adding it invites the
/// recipient to read it as such — the barcode header, which *is* the evidence
/// on that path, does travel. And **the origin-preference marks**, because
/// they are the sender's own settings and mean nothing to anyone else.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.report});

  final ProductReport report;

  /// Fixed width, portrait proportions. Captured at this size rather than at
  /// whatever the phone happens to be, so the output is identical on every
  /// device and legible when a chat app scales it down.
  static const double width = 1080;

  @override
  Widget build(BuildContext context) {
    final claims = <(String, ProvenanceClaim)>[
      ('Brand registered in', report.registeredIn),
      ('Manufactured in', report.manufacturedIn),
      ('Headquarters', report.headquarters),
      if (report.taxJurisdiction != null)
        ('Profit booked in', report.taxJurisdiction!),
    ];

    return Container(
      width: width,
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.source == ScanSource.barcode && report.barcode != null)
            _BarcodeLine(barcode: report.barcode!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  report.productName.hasValue
                      ? report.productName.displayValue
                      : 'Product not identified',
                  style: AppText.display.copyWith(fontSize: 64, height: 1.1),
                ),
              ),
              const SizedBox(width: 20),
              Transform.scale(
                scale: 2.2,
                alignment: Alignment.topRight,
                child: ProvenanceBadge(report.productName.provenance),
              ),
            ],
          ),
          if (report.brand.hasValue) ...[
            const SizedBox(height: 12),
            Text(
              'by ${report.brand.displayValue}',
              style: AppText.caption.copyWith(fontSize: 30),
            ),
          ],
          const SizedBox(height: 44),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                for (var i = 0; i < claims.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 2, thickness: 2, color: AppColors.border),
                  _ShareClaimRow(label: claims[i].$1, claim: claims[i].$2),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _ShareLegend(),
        ],
      ),
    );
  }
}

class _BarcodeLine extends StatelessWidget {
  const _BarcodeLine({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 44, color: AppColors.brand),
          const SizedBox(width: 16),
          Text(
            barcode,
            style: AppText.title.copyWith(
              fontSize: 36,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareClaimRow extends StatelessWidget {
  const _ShareClaimRow({required this.label, required this.claim});

  final String label;
  final ProvenanceClaim claim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppText.label.copyWith(fontSize: 24, letterSpacing: 1.6),
                ),
              ),
              Transform.scale(
                scale: 1.9,
                alignment: Alignment.centerRight,
                child: ProvenanceBadge(claim.provenance, compact: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            claim.displayValue,
            style: claim.hasValue
                ? AppText.bodyStrong.copyWith(fontSize: 40)
                : AppText.body.copyWith(fontSize: 40, color: AppColors.inkMuted),
          ),
          if (claim.source != null) ...[
            const SizedBox(height: 8),
            Text(
              claim.source!,
              style: AppText.caption.copyWith(fontSize: 24),
            ),
          ],
        ],
      ),
    );
  }
}

/// Travels with the card, every time.
class _ShareLegend extends StatelessWidget {
  const _ShareLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW TO READ THIS',
            style: AppText.label.copyWith(fontSize: 24, letterSpacing: 1.6),
          ),
          const SizedBox(height: 24),
          for (final provenance in Provenance.values) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Align, so the badge keeps its intrinsic width inside the
                // fixed column. Without it the SizedBox stretches the pill to
                // 230 and the scale then multiplies *that*, sliding the
                // background out from under its own label and behind the
                // explanation text.
                SizedBox(
                  width: 230,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.scale(
                      scale: 1.9,
                      alignment: Alignment.centerLeft,
                      child: ProvenanceBadge(provenance, compact: true),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    provenance.explanation,
                    style: AppText.caption.copyWith(fontSize: 24, height: 1.4),
                  ),
                ),
              ],
            ),
            if (provenance != Provenance.values.last)
              const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
