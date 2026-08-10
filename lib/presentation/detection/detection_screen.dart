import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/error/app_error.dart';
import '../../data/ai/on_device_ai_service.dart';
import '../../data/open_food_facts/open_food_facts_api.dart';
import '../../data/recognition/recognition_api_dio.dart';
import '../../domain/models/product_report.dart';
import '../../domain/models/report_from_barcode.dart';
import '../../domain/models/report_from_recognition.dart';
import '../barcode/barcode_scanner_screen.dart';
import '../camera/camera_capture_screen.dart';
import '../design/tokens.dart';
import '../history/history_tab.dart';
import '../history/history_view_model.dart';
import '../preferences/origin_preferences_tab.dart';
import '../preferences/origin_preferences_view_model.dart';
import '../report/product_report_view.dart';
import '../report/scan_result_screen.dart';
import '../saved/saved_products_view_model.dart';
import '../saved/saved_tab.dart';
import 'detection_view_model.dart';
import 'widgets/analyzing_overlay.dart';
import 'widgets/confirm_photo_view.dart';
import 'widgets/detection_error_view.dart';
import 'widgets/detection_nav_bar.dart';
import 'widgets/scan_home_view.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  late final DetectionViewModel _viewModel;
  final OnDeviceAIService _detector = OnDeviceAIService();

  @override
  void initState() {
    super.initState();
    _viewModel = DetectionViewModel(
      recognitionApi: RecognitionApiDio(),
      // The offline half of the pipeline. It looks at the photograph before
      // anything leaves the phone and says whether there is a recognisable
      // object in it at all.
      objectDetector: _detector,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _viewModel),
        ChangeNotifierProvider(create: (_) => SavedProductsViewModel()),
        ChangeNotifierProvider(create: (_) => HistoryViewModel()),
        ChangeNotifierProvider(create: (_) => OriginPreferencesViewModel()),
      ],
      child: const _DetectionHome(),
    );
  }
}

class _DetectionHome extends StatefulWidget {
  const _DetectionHome();

  @override
  State<_DetectionHome> createState() => _DetectionHomeState();
}

class _DetectionHomeState extends State<_DetectionHome> {
  int _currentIndex = 0;
  ScanMode _scanMode = ScanMode.photo;

  /// Held here rather than in a view model: the barcode path is a single
  /// request with no state to keep between scans, and the only thing the UI
  /// needs to know is whether it is in flight.
  final OpenFoodFactsApi _openFoodFacts = OpenFoodFactsApi();
  bool _isLookingUpBarcode = false;
  String? _barcodeError;

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  /// Camera → confirm → analyse → result, as one readable sequence.
  ///
  /// This used to be spread across a build method: a post-frame callback wrote
  /// the history row, a `_lastHistoryImagePath` field stopped it firing twice
  /// on rebuild, and the result was a widget chosen by a three-deep ternary on
  /// view-model flags. Writing it as a sequence removes the dedupe field
  /// outright — history is written once, at the one moment a scan completes —
  /// and makes the navigation impossible to reach from a rebuild.
  Future<void> _startPhotoScan({required bool fromGallery}) async {
    final viewModel = context.read<DetectionViewModel>();

    if (fromGallery) {
      await viewModel.pickFromGallery();
      if (!viewModel.hasImage) return;
    } else {
      final captured = await Navigator.of(context).push<File>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
      if (captured == null) return;
      viewModel.setImage(captured);
    }

    // Fire-and-forget on purpose: the request goes out while the user is still
    // looking at the confirmation, so confirming usually costs no wait at all.
    unawaited(viewModel.preAnalyzeImage());
  }

  Future<void> _confirmAndShowResult() async {
    final viewModel = context.read<DetectionViewModel>();
    final historyViewModel = context.read<HistoryViewModel>();
    final savedViewModel = context.read<SavedProductsViewModel>();
    final navigator = Navigator.of(context);

    await viewModel.confirmAnalysis();

    final result = viewModel.result;
    final imageFile = viewModel.imageFile;
    // Failure leaves `errorMessage` set, and the scan tab renders
    // DetectionErrorView for it. Nothing to navigate to.
    if (result == null || imageFile == null) return;

    final report = result.toReport(imagePath: imageFile.path);
    await historyViewModel.addFromResult(
      report: report,
      resultText: result.message,
      imageFile: imageFile,
      productionOrigin: result.productionOrigin,
      hqCountry: result.hqCountry,
      taxCountry: result.taxCountry,
    );

    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          // The pushed route is outside the tab subtree, so the view models it
          // needs are handed over explicitly. `.value` because they are owned
          // by the tabs and must outlive this route.
          providers: [
            ChangeNotifierProvider.value(value: savedViewModel),
          ],
          child: ScanResultScreen(
            report: report,
            imageFile: imageFile,
            result: result,
          ),
        ),
      ),
    );

    if (!mounted) return;
    // Back from the result means the scan is over. Clearing here rather than
    // leaving the last photo on screen is what makes the tab an entry point
    // again instead of a stale result.
    viewModel.reset();
  }

  /// Scanner → registry → result.
  ///
  /// Note what happens when Open Food Facts has never heard of the barcode:
  /// the report is still built and still shown. The GS1 prefix decodes offline
  /// from the digits themselves, so there is a real, attributable answer to
  /// give even with no database record — and an error page instead would throw
  /// away the one claim on this path that is genuinely reproducible.
  Future<void> _startBarcodeScan() async {
    final navigator = Navigator.of(context);
    final historyViewModel = context.read<HistoryViewModel>();
    final savedViewModel = context.read<SavedProductsViewModel>();

    final barcode = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    setState(() {
      _isLookingUpBarcode = true;
      _barcodeError = null;
    });

    Map<String, dynamic>? product;
    String? failure;
    try {
      product = await _openFoodFacts.fetchProduct(barcode);
    } on AppException catch (error) {
      // A lookup that failed is not a lookup that came back empty, and the
      // two must not collapse into the same screen: "not in the database" is
      // an answer, "the network is down" is a retry.
      failure = error.message;
    }

    if (!mounted) return;
    setState(() {
      _isLookingUpBarcode = false;
      _barcodeError = failure;
    });
    if (failure != null) return;

    final report = reportFromBarcode(barcode, openFoodFactsProduct: product);
    // No image, and the row is worth keeping anyway: it carries a Verified
    // registry reading, which is the strongest claim the app can make. The
    // stored record keeps the badges now, so reopening it from history shows
    // the same Verified it showed here rather than a downgraded guess.
    await historyViewModel.addFromResult(report: report);

    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => _BarcodeResultRoute(
          report: report,
          savedViewModel: savedViewModel,
        ),
      ),
    );
  }

  Future<void> _retakeAfterConfirm() async {
    context.read<DetectionViewModel>().cancelPendingAnalysis();
    await _startPhotoScan(fromGallery: false);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetectionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                _ScanTab(
                  viewModel: viewModel,
                  mode: _scanMode,
                  barcodeError: _barcodeError,
                  onModeChanged: (mode) => setState(() {
                    _scanMode = mode;
                    _barcodeError = null;
                  }),
                  onOpenCamera: () => _startPhotoScan(fromGallery: false),
                  onPickFromGallery: () => _startPhotoScan(fromGallery: true),
                  onScanBarcode: _startBarcodeScan,
                  onConfirm: _confirmAndShowResult,
                  onRetake: _retakeAfterConfirm,
                ),
                // The empty states offer a way out, and the way out is a tab
                // switch the tabs cannot perform themselves.
                SavedTab(onStartScan: () => _onTabSelected(0)),
                HistoryTab(onStartScan: () => _onTabSelected(0)),
                const OriginPreferencesTab(),
              ],
            ),
            if (viewModel.isLoading) const AnalyzingOverlay.photo(),
            if (_isLookingUpBarcode) const AnalyzingOverlay.barcode(),
          ],
        ),
      ),
      bottomNavigationBar: viewModel.isLoading ||
              viewModel.isAwaitingConfirmation ||
              _isLookingUpBarcode
          ? null
          : DetectionNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
            ),
    );
  }
}

/// The result of a barcode scan.
///
/// Its own widget rather than an inline `ProductReportView` so the bookmark
/// reflects the saved state as it changes: the route sits outside the tab
/// subtree, so the view model is handed over explicitly and watched here.
class _BarcodeResultRoute extends StatelessWidget {
  const _BarcodeResultRoute({
    required this.report,
    required this.savedViewModel,
  });

  final ProductReport report;
  final SavedProductsViewModel savedViewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: savedViewModel,
      child: Consumer<SavedProductsViewModel>(
        builder: (context, saved, _) => ProductReportView(
          report: report,
          isSaved: saved.isBarcodeSaved(report.barcode),
          onSave: () => saved.toggleFromResult(report: report),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// The scan tab has three states and shows exactly one of them.
class _ScanTab extends StatelessWidget {
  const _ScanTab({
    required this.viewModel,
    required this.mode,
    required this.barcodeError,
    required this.onModeChanged,
    required this.onOpenCamera,
    required this.onPickFromGallery,
    required this.onScanBarcode,
    required this.onConfirm,
    required this.onRetake,
  });

  final DetectionViewModel viewModel;
  final ScanMode mode;
  final String? barcodeError;
  final ValueChanged<ScanMode> onModeChanged;
  final VoidCallback onOpenCamera;
  final VoidCallback onPickFromGallery;
  final VoidCallback onScanBarcode;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final imageFile = viewModel.imageFile;

    if (viewModel.isAwaitingConfirmation && imageFile != null) {
      return ConfirmPhotoView(
        imageFile: imageFile,
        onConfirm: onConfirm,
        onRetake: onRetake,
        frameCheck: viewModel.frameCheck,
        frameSummary: viewModel.frameSummary,
      );
    }

    final error = barcodeError ??
        (viewModel.isLoading ? null : viewModel.errorMessage);
    if (error != null) {
      final isBarcode = barcodeError != null;
      return DetectionErrorView(
        message: error,
        onRetry: isBarcode ? onScanBarcode : onOpenCamera,
        onPickFromGallery: onPickFromGallery,
        retryLabel: isBarcode ? 'Scan again' : 'Try again',
        retryIcon: isBarcode
            ? Icons.qr_code_scanner
            : Icons.photo_camera_outlined,
      );
    }

    return ScanHomeView(
      mode: mode,
      onModeChanged: onModeChanged,
      onOpenCamera: onOpenCamera,
      onPickFromGallery: onPickFromGallery,
      onScanBarcode: onScanBarcode,
      isBusy: viewModel.isLoading,
    );
  }
}
