import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with TickerProviderStateMixin {
  static const Color _accentBlue = Color(0xFF1A497F);
  CameraController? _controller;
  CameraDescription? _backCamera;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device.';
          _isInitializing = false;
        });
        return;
      }

      _backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _startController(_backCamera!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Camera error: $error';
        _isInitializing = false;
      });
    }
  }

  Future<void> _startController(CameraDescription description) async {
    final previousController = _controller;
    _controller = null;
    if (previousController != null) {
      await previousController.dispose();
    }
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);
    await _resetZoom(controller);
    await _warmUpCapture(controller);

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller?.dispose();
      _controller = controller;
      _flashOn = false;
      _isInitializing = false;
    });
  }

  Future<void> _warmUpCapture(CameraController controller) async {
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!controller.value.isInitialized || controller.value.isTakingPicture) {
        return;
      }
      final file = await controller.takePicture();
      final tempFile = File(file.path);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {
      // Ignore warm-up errors; user capture will still work normally.
    }
  }

  Future<void> _resetZoom(CameraController controller) async {
    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final targetZoom = 1.0.clamp(minZoom, maxZoom);
      await controller.setZoomLevel(targetZoom);
    } catch (_) {
      // Some devices don't support zoom controls; ignore silently.
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      final nextMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(nextMode);
      if (!mounted) return;
      setState(() {
        _flashOn = !_flashOn;
      });
      await HapticFeedback.lightImpact();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this camera.')),
      );
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
    });
    await HapticFeedback.mediumImpact();

    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<File>(File(image.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $error')),
      );
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isInitializing || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accentBlue,
          strokeWidth: 3,
        ),
      );
    }

    final controller = _controller!;
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 1,
                  height: controller.value.previewSize?.width ?? 1,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(child: _GridOverlay()),
        Positioned(
          top: 44,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: _CameraTopBar(
              isFlashOn: _flashOn,
              onFlashToggle: _toggleFlash,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _CaptureButton(
                isCapturing: _isCapturing,
                accentColor: _accentBlue,
                onTap: _isCapturing ? null : _capture,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;

    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    for (int i = 1; i <= 2; i++) {
      final dx = thirdWidth * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }

    for (int i = 1; i <= 2; i++) {
      final dy = thirdHeight * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar({
    required this.isFlashOn,
    required this.onFlashToggle,
  });

  final bool isFlashOn;
  final VoidCallback onFlashToggle;

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF1A497F);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CameraIconButton(
          icon: Icons.arrow_back_ios_new,
          size: 40,
          iconSize: 30,
          iconColor: iconColor,
          onTap: () => Navigator.of(context).pop(),
        ),
        _CameraIconButton(
          icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
          size: 30,
          iconSize: 30,
          iconColor: iconColor,
          onTap: onFlashToggle,
        ),
      ],
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.iconSize,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isCapturing,
    required this.accentColor,
    required this.onTap,
  });

  final bool isCapturing;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0B2F5B), width: 2),
          color: Colors.white.withOpacity(0.2),
        ),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() {
                _pressed = true;
              }),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() {
                _pressed = false;
              }),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() {
                _pressed = false;
              }),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.94 : 1,
        child: widget.child,
      ),
    );
  }
}
