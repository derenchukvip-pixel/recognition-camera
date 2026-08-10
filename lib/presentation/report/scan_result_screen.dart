import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/product_report.dart';
import '../../domain/models/recognition_result.dart';
import '../saved/saved_products_view_model.dart';
import 'product_report_view.dart';

/// The result of a live photo scan.
///
/// A thin shell around [ProductReportView] that supplies the two things the
/// pure view refuses to know about: how to render a `File` from the camera,
/// and whether this scan is currently bookmarked. Keeping them out here is
/// what lets the same result screen render in the web preview, where there is
/// no file system and no Hive box.
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({
    super.key,
    required this.report,
    required this.imageFile,
    required this.result,
  });

  final ProductReport report;
  final File imageFile;

  /// The raw recognition response. Needed only for the save payload: the
  /// stored record still has the old flat shape, so it is written from the
  /// original strings rather than from [report].
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedProductsViewModel>();

    return ProductReportView(
      report: report,
      imageBuilder: (_) => Image.file(imageFile, fit: BoxFit.cover),
      isSaved: saved.isSaved(imageFile.path),
      onSave: () => saved.toggleFromResult(
        productName: result.productName ?? 'Not identified',
        companyName: result.companyName ?? 'Unknown company',
        imageFile: imageFile,
        productionOrigin: result.productionOrigin,
        hqCountry: result.hqCountry,
        taxCountry: result.taxCountry,
        resultText: result.message,
      ),
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
