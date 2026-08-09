import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recognition/recognition_api_dio.dart';
import '../../domain/models/report_from_recognition.dart';
import '../camera/camera_capture_screen.dart';
import '../design/tokens.dart';
import '../history/history_tab.dart';
import '../history/history_view_model.dart';
import '../preferences/origin_preferences_tab.dart';
import '../preferences/origin_preferences_view_model.dart';
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

  @override
  void initState() {
    super.initState();
    _viewModel = DetectionViewModel(recognitionApi: RecognitionApiDio());
  }

  @override
  void dispose() {
    _viewModel.dispose();
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

    await historyViewModel.addFromResult(
      productName: result.productName ?? 'Not identified',
      companyName: result.companyName ?? 'Unknown company',
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
            report: result.toReport(imagePath: imageFile.path),
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
                  onOpenCamera: () => _startPhotoScan(fromGallery: false),
                  onPickFromGallery: () => _startPhotoScan(fromGallery: true),
                  onConfirm: _confirmAndShowResult,
                  onRetake: _retakeAfterConfirm,
                ),
                const SavedTab(),
                const HistoryTab(),
                const OriginPreferencesTab(),
              ],
            ),
            if (viewModel.isLoading) const AnalyzingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar:
          viewModel.isLoading || viewModel.isAwaitingConfirmation
              ? null
              : DetectionNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabSelected,
                ),
    );
  }
}

/// The scan tab has three states and shows exactly one of them.
class _ScanTab extends StatelessWidget {
  const _ScanTab({
    required this.viewModel,
    required this.onOpenCamera,
    required this.onPickFromGallery,
    required this.onConfirm,
    required this.onRetake,
  });

  final DetectionViewModel viewModel;
  final VoidCallback onOpenCamera;
  final VoidCallback onPickFromGallery;
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
      );
    }

    final error = viewModel.errorMessage;
    if (!viewModel.isLoading && error != null) {
      return DetectionErrorView(
        message: error,
        onRetry: onOpenCamera,
        onPickFromGallery: onPickFromGallery,
      );
    }

    return ScanHomeView(
      onOpenCamera: onOpenCamera,
      onPickFromGallery: onPickFromGallery,
      isBusy: viewModel.isLoading,
    );
  }
}
