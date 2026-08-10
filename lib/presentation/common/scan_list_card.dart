import 'package:flutter/material.dart';

import '../../domain/models/product_report.dart';
import '../design/provenance_badge.dart';
import '../design/tokens.dart';

/// One past scan, in a list.
///
/// The badge is the reason this is a shared widget rather than two similar
/// ones. Both lists have to answer "how much of this was actually verified"
/// before the row is opened — otherwise a Verified barcode reading and a
/// model's guess look identical until you tap them, and the distinction the
/// whole app is built around only exists on the detail screen.
///
/// The badge shown is the one on the product name, because that is the claim
/// the row's title is making. It is not a summary of the whole report; a row
/// can read Estimated and still hold a Verified registry country inside.
class ScanListCard extends StatelessWidget {
  const ScanListCard({
    super.key,
    required this.report,
    required this.onTap,
    this.thumbnailBuilder,
    this.trailing,
  });

  final ProductReport report;

  /// Renders the stored photo, or null when there is none to render.
  ///
  /// A builder rather than a path, for the same reason [ProductReportView]
  /// takes one: the phone resolves a `File`, the web preview resolves an
  /// asset, and a widget that imported `dart:io` to do it itself could not be
  /// compiled for the preview at all. Deciding *whether* a photo exists is
  /// the caller's job too — this card only knows what to draw when it does
  /// not.
  final WidgetBuilder? thumbnailBuilder;

  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final name = report.productName;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _Thumbnail(report: report, builder: thumbnailBuilder),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.hasValue
                          ? name.displayValue
                          : 'Product not identified',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: name.hasValue
                          ? AppText.bodyStrong
                          : AppText.body.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(report),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ProvenanceBadge(name.provenance, compact: true),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand when there is one, the barcode when there is not, and an honest
/// blank when neither. Never a filler string — a row that says "Unknown
/// company" where a brand goes is asserting something the app never found.
String _subtitle(ProductReport report) {
  if (report.brand.hasValue) return report.brand.displayValue;
  if (report.barcode != null && report.barcode!.isNotEmpty) {
    return report.barcode!;
  }
  return 'Brand not identified';
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.report, this.builder});

  final ProductReport report;
  final WidgetBuilder? builder;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: SizedBox(
        width: 56,
        height: 56,
        child: ColoredBox(
          color: AppColors.surfaceSubtle,
          child: builder != null
              ? builder!(context)
              // A barcode scan has no photograph and gets the mark of what it
              // does have. A generic broken-image glyph would read as a
              // missing file rather than as a different kind of scan.
              : Icon(
                  report.source == ScanSource.barcode
                      ? Icons.qr_code_2
                      : Icons.image_not_supported_outlined,
                  color: AppColors.inkMuted,
                ),
        ),
      ),
    );
  }
}
