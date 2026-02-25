import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recognition/recognition_api_dio.dart';
import '../camera/camera_capture_screen.dart';
import '../history/history_tab.dart';
import '../history/history_view_model.dart';
import '../preferences/origin_preferences_tab.dart';
import '../preferences/origin_preferences_view_model.dart';
import '../saved/saved_products_view_model.dart';
import '../saved/saved_tab.dart';
import 'detection_view_model.dart';

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
  String? _lastHistoryImagePath;

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openCameraFromConfirmation(DetectionViewModel viewModel) async {
    final capturedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (capturedFile != null) {
      viewModel.setImage(capturedFile);
      unawaited(viewModel.preAnalyzeImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetectionViewModel>();
    final savedViewModel = context.watch<SavedProductsViewModel>();
    final historyViewModel = context.watch<HistoryViewModel>();

    if (viewModel.resultText != null &&
        !viewModel.isLoading &&
        !viewModel.isAwaitingConfirmation &&
        viewModel.imageFile != null &&
        _lastHistoryImagePath != viewModel.imageFile!.path) {
      _lastHistoryImagePath = viewModel.imageFile!.path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        historyViewModel.addFromResult(
          productName: viewModel.productName ?? 'Unknown product',
          companyName: viewModel.hqCountry ?? 'Unknown company',
          resultText: viewModel.resultText ?? '',
          imageFile: viewModel.imageFile!,
          productionOrigin: viewModel.productionOrigin,
          hqCountry: viewModel.hqCountry,
          taxCountry: viewModel.taxCountry,
        );
      });
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                viewModel.isAwaitingConfirmation &&
                        viewModel.imageFile != null
                    ? _ConfirmPhotoView(
                        imageFile: viewModel.imageFile!,
                        onConfirm: viewModel.confirmAnalysis,
                        onRetake: () async {
                          viewModel.cancelPendingAnalysis();
                          await _openCameraFromConfirmation(viewModel);
                        },
                      )
                    : viewModel.resultText != null && !viewModel.isLoading
                        ? _AnalyzedImageView(
                            productName: viewModel.productName,
                            productionOrigin: viewModel.productionOrigin,
                            hqCountry: viewModel.hqCountry,
                            taxCountry: viewModel.taxCountry,
                            imageFile: viewModel.imageFile,
                            onClose: viewModel.reset,
                            onOpenPreferences: () => _onTabSelected(3),
                            isSaved: viewModel.imageFile != null &&
                                savedViewModel
                                    .isSaved(viewModel.imageFile!.path),
                            onSave: () {
                              final imageFile = viewModel.imageFile;
                              if (imageFile == null) return;
                              savedViewModel.toggleFromResult(
                                productName: viewModel.productName ??
                                    'Unknown product',
                                companyName:
                                    viewModel.hqCountry ?? 'Unknown company',
                                imageFile: imageFile,
                                productionOrigin: viewModel.productionOrigin,
                                hqCountry: viewModel.hqCountry,
                                taxCountry: viewModel.taxCountry,
                                resultText: viewModel.resultText,
                              );
                            },
                          )
                        : const _DetectionScreenView(),
                const SavedTab(),
                const HistoryTab(),
                const OriginPreferencesTab(),
              ],
            ),
            if (viewModel.isLoading) const _AnalyzingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: viewModel.isLoading || viewModel.isAwaitingConfirmation
          ? null
          : _BottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
            ),
    );
  }
}

class _DetectionScreenView extends StatelessWidget {
  const _DetectionScreenView();

  static const Color _primaryBlue = Color(0xFF052F61);

  Future<void> _openCamera(
    BuildContext context,
    DetectionViewModel viewModel,
  ) async {
    final capturedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (capturedFile != null) {
      viewModel.setImage(capturedFile);
      unawaited(viewModel.preAnalyzeImage());
    }
  }

  Future<void> _pickFromGallery(
    BuildContext context,
    DetectionViewModel viewModel,
  ) async {
    await viewModel.pickFromGallery();
    if (viewModel.hasImage) {
      final imageFile = viewModel.imageFile;
      if (imageFile == null) return;
      unawaited(viewModel.preAnalyzeImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetectionViewModel>();

    if (!viewModel.isLoading && viewModel.errorMessage != null) {
      return _DetectionErrorView(
        message: viewModel.errorMessage!,
        onClose: viewModel.reset,
        onOpenCamera: () => _openCamera(context, viewModel),
        onUpload: () => _pickFromGallery(context, viewModel),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Center(child: _ScanBox(imageFile: viewModel.imageFile)),
          const SizedBox(height: 24),
          SizedBox(
            width: 240,
            height: 44,
            child: FilledButton(
              onPressed: viewModel.isLoading
                  ? null
                  : () => _openCamera(context, viewModel),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Open Camera'),
                  const SizedBox(width: 12),
                  Image.asset(
                    'materials/Icons/photo_camera.png',
                    width: 20,
                    height: 20,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            height: 44,
            child: OutlinedButton(
              onPressed: viewModel.isLoading
                  ? null
                  : () => _pickFromGallery(context, viewModel),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryBlue,
                side: const BorderSide(color: _primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Upload Picture'),
                  const SizedBox(width: 12),
                  Image.asset(
                    'materials/Icons/ios_share.png',
                    width: 20,
                    height: 20,
                    color: _primaryBlue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (viewModel.isLoading) const _LoadingRow(),
          if (!viewModel.isLoading && viewModel.resultText != null)
            ResultTextCard(text: viewModel.resultText!),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _ConfirmPhotoView extends StatelessWidget {
  const _ConfirmPhotoView({
    required this.imageFile,
    required this.onConfirm,
    required this.onRetake,
  });

  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  static const Color _primaryBlue = Color(0xFF052F61);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Confirm Photo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'This photo will be used to recognise your product',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryBlue,
                      side: const BorderSide(color: _primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Use Photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionErrorView extends StatelessWidget {
  const _DetectionErrorView({
    required this.message,
    required this.onClose,
    required this.onOpenCamera,
    required this.onUpload,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback onOpenCamera;
  final VoidCallback onUpload;

  static const Color _primaryBlue = Color(0xFF052F61);

  @override
  Widget build(BuildContext context) {
    final displayMessage = message.isNotEmpty
        ? message
        : 'Upload unsuccessful.\nPlease try again.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, color: _primaryBlue, size: 30),
            ),
          ),
          const Spacer(flex: 2),
          const _ErrorIcon(),
          const SizedBox(height: 16),
          Text(
            displayMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 220,
            height: 44,
            child: FilledButton.icon(
              onPressed: onOpenCamera,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Image.asset(
                'materials/Icons/photo_camera.png',
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              label: const Text('Open Camera'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryBlue,
                side: const BorderSide(color: _primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Image.asset(
                'materials/Icons/ios_share.png',
                width: 20,
                height: 20,
                color: _primaryBlue,
              ),
              label: const Text('Upload Picture'),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _ErrorIcon extends StatelessWidget {
  const _ErrorIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB11C1C), width: 3),
            ),
          ),
          const Icon(
            Icons.refresh,
            color: Color(0xFFB11C1C),
            size: 30,
          ),
          const Positioned(
            right: 12,
            top: 12,
            child: Icon(
              Icons.close,
              color: Color(0xFFB11C1C),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF052F61),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analysing your image...\nThis may take a moment.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1A497F),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzedImageView extends StatelessWidget {
  const _AnalyzedImageView({
    required this.productName,
    required this.productionOrigin,
    required this.hqCountry,
    required this.taxCountry,
    required this.imageFile,
    required this.onClose,
    required this.onOpenPreferences,
    required this.isSaved,
    required this.onSave,
  });

  final String? productName;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;
  final File? imageFile;
  final VoidCallback onClose;
  final VoidCallback onOpenPreferences;
  final bool isSaved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<OriginPreferencesViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onSave,
                icon: isSaved
                    ? Image.asset(
                        'materials/Icons/bookmark_filled.png',
                        width: 30,
                        height: 30,
                        color: const Color(0xFF052F61),
                      )
                    : Image.asset(
                        'materials/Icons/bookmark.png',
                        width: 30,
                        height: 30,
                        color: const Color(0xFF052F61),
                      ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Image.asset(
                  'materials/Icons/close.png',
                  width: 30,
                  height: 30,
                  color: const Color(0xFF052F61),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Analysed Image',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF052F61),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI-generated insights from your latest image',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 16),
          Transform.translate(
            offset: const Offset(-24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: MediaQuery.of(context).size.width - 96,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A497F),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imageFile == null
                            ? const SizedBox.shrink()
                            : Image.file(imageFile!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _InfoRow(
            label: 'Product:',
            value: productName ?? 'Not found',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Company:',
            value: hqCountry ?? 'Not found',
          ),
          const SizedBox(height: 16),
          _InfoSplitRow(
            label: 'Production',
            value: productionOrigin ?? 'Not found',
            onStatusTap: onOpenPreferences,
            preferences: preferences,
          ),
          const Divider(height: 24),
          _InfoSplitRow(
            label: 'Tax & Profit',
            value: taxCountry ?? 'Not found',
            onStatusTap: onOpenPreferences,
            preferences: preferences,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF052F61),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _InfoSplitRow extends StatelessWidget {
  const _InfoSplitRow({
    required this.label,
    required this.value,
    this.onStatusTap,
    required this.preferences,
  });

  final String label;
  final String value;
  final VoidCallback? onStatusTap;
  final OriginPreferencesViewModel preferences;

  @override
  Widget build(BuildContext context) {
    final lines = _parseCountryLines(value, preferences);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF052F61),
                ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _lineColor(line.status),
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Column(
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: line.status == null
                      ? const SizedBox(height: 20, width: 20)
                      : InkResponse(
                          onTap: onStatusTap,
                          child: Icon(
                            line.status == _CountryStatus.aligned
                                ? Icons.verified
                                : Icons.warning_amber_rounded,
                            size: 20,
                            color: line.status == _CountryStatus.aligned
                                ? const Color(0xFF1A7F4A)
                                : const Color(0xFFB11C1C),
                          ),
                        ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

enum _CountryStatus { aligned, misaligned }

class _CountryLine {
  const _CountryLine({required this.text, this.status});

  final String text;
  final _CountryStatus? status;
}

List<_CountryLine> _parseCountryLines(
  String value,
  OriginPreferencesViewModel preferences,
) {
  final parts = value
      .split(RegExp(r'[\n,]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return [const _CountryLine(text: 'Not found')];
  }
  return parts
      .map((part) {
        final lower = part.toLowerCase();
        if (lower.contains('other countries')) {
          return _CountryLine(text: part, status: null);
        }
        if (preferences.matchesAligned(part)) {
          return _CountryLine(text: part, status: _CountryStatus.aligned);
        }
        if (preferences.matchesLessAligned(part)) {
          return _CountryLine(text: part, status: _CountryStatus.misaligned);
        }
        return _CountryLine(text: part, status: null);
      })
      .toList();
}

Color _lineColor(_CountryStatus? status) {
  if (status == _CountryStatus.aligned) {
    return const Color(0xFF1A7F4A);
  }
  if (status == _CountryStatus.misaligned) {
    return const Color(0xFFB11C1C);
  }
  return Colors.black87;
}

class _ScanBox extends StatelessWidget {
  const _ScanBox({this.imageFile});

  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: imageFile == null
            ? const SizedBox.shrink()
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(imageFile!, fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const Color borderColor = Color(0xFF052F61);
    const double strokeWidth = 3;
    final Paint paint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final inset = size.width * 0.06;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final cornerRadius = rect.width * 0.14;

    final innerWidth = rect.width - cornerRadius * 2;
    final innerHeight = rect.height - cornerRadius * 2;
    final segmentLength = math.min(innerWidth, innerHeight) * 0.24;

    void drawCenterHorizontal(double y) {
      final x1 = rect.center.dx - segmentLength / 2;
      final x2 = rect.center.dx + segmentLength / 2;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    }

    void drawCenterVertical(double x) {
      final y1 = rect.center.dy - segmentLength / 2;
      final y2 = rect.center.dy + segmentLength / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }

    drawCenterHorizontal(rect.top);
    drawCenterHorizontal(rect.bottom);
    drawCenterVertical(rect.left);
    drawCenterVertical(rect.right);

    final arcPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final radius = cornerRadius;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.left + radius, rect.top + radius),
        radius: radius,
      ),
      math.pi,
      math.pi / 2,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.right - radius, rect.top + radius),
        radius: radius,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.right - radius, rect.bottom - radius),
        radius: radius,
      ),
      0,
      math.pi / 2,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.left + radius, rect.bottom - radius),
        radius: radius,
      ),
      math.pi / 2,
      math.pi / 2,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _secondaryBlue = Color(0xFF1A497F);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: _secondaryBlue,
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _BottomNavItem(
              assetPath: 'materials/Icons/photo_camera.png',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _BottomNavItem(
              assetPath: 'materials/Icons/bookmark.png',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _BottomNavItem(
              assetPath: 'materials/Icons/history.png',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _BottomNavItem(
              assetPath: 'materials/Icons/brightness_5.png',
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;
  static const Color _primaryBlue = Color(0xFF052F61);

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
        isSelected ? Colors.white : Colors.white.withOpacity(0.72);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected ? _primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.zero,
            ),
            child: Center(
              child: Image.asset(
                assetPath,
                width: 30,
                height: 30,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Analyzing...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class ResultTextCard extends StatelessWidget {
  const ResultTextCard({
    super.key,
    required this.text,
    this.textColor,
  });

  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor ?? Colors.black,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
