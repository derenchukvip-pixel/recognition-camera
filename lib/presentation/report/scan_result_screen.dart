import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/product_report.dart';
import '../../domain/models/recognition_result.dart';
import '../saved/saved_products_view_model.dart';
import 'report_screen.dart';

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

  /// The raw recognition response. The badges are saved from [report]; these
  /// strings ride along so the row also stays readable to the legacy path
  /// that reconstructs a report from loose text.
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedProductsViewModel>();

    return ReportScreen(
      report: report,
      imageBuilder: (_) => Image.file(imageFile, fit: BoxFit.cover),
      isSaved: saved.isSaved(imageFile.path),
      onSave: () => saved.toggleFromResult(
        report: report,
        imageFile: imageFile,
        productionOrigin: result.productionOrigin,
        hqCountry: result.hqCountry,
        taxCountry: result.taxCountry,
        resultText: result.message,
      ),
    );
  }
}
