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
  CameraController? _controller;
  CameraDescription? _backCamera;
  CameraDescription? _frontCamera;
  CameraDescription? _activeCamera;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  bool _flashOn = false;
  late final AnimationController _framePulseController;
  late final AnimationController _frameFlashController;
  late final Animation<double> _framePulse;
  late final Animation<double> _frameFlash;

  @override
  void initState() {
    super.initState();
    _framePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _frameFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _framePulse = CurvedAnimation(
      parent: _framePulseController,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 0.15, end: 0.55));
    _frameFlash = CurvedAnimation(
      parent: _frameFlashController,
      curve: Curves.easeOutCubic,
    ).drive(Tween(begin: 0.0, end: 1.0));
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
      _frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _backCamera!,
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
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);
    await _resetZoom(controller);

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller?.dispose();
      _controller = controller;
      _activeCamera = description;
      _flashOn = false;
      _isInitializing = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_isInitializing || _isCapturing) return;
    if (_backCamera == null || _frontCamera == null) return;
    if (_backCamera == _frontCamera) return;
    final nextCamera = _activeCamera?.lensDirection == CameraLensDirection.front
        ? _backCamera
        : _frontCamera;
    setState(() {
      _isInitializing = true;
    });
    await HapticFeedback.selectionClick();
    await _startController(nextCamera!);
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
    _frameFlashController.forward(from: 0);

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
    _framePulseController.dispose();
    _frameFlashController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Camera'),
        backgroundColor: Colors.black.withOpacity(0.4),
        foregroundColor: Colors.white,
      ),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_controller!)),
        Positioned.fill(child: _GradientOverlay()),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _framePulseController,
              _frameFlashController,
            ]),
            builder: (context, child) {
              return _CameraFrameOverlay(
                pulse: _framePulse.value,
                flash: _frameFlash.value,
              );
            },
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _CameraTopBar(
            isFlashOn: _flashOn,
            canSwitch: _backCamera != null && _frontCamera != null,
            onFlashToggle: _toggleFlash,
            onSwitchCamera: _switchCamera,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Align the product inside the frame',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _CaptureButton(
                isCapturing: _isCapturing,
                accentColor: theme.colorScheme.primary,
                onTap: _isCapturing ? null : _capture,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraFrameOverlay extends StatelessWidget {
  const _CameraFrameOverlay({
    required this.pulse,
    required this.flash,
  });

  final double pulse;
  final double flash;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth * 0.76;
        final frameHeight = constraints.maxHeight * 0.42;
        final glowStrength = (pulse + flash).clamp(0.0, 1.0);

        return Stack(
          children: [
            Center(
              child: Container(
                width: frameWidth,
                height: frameHeight,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45 + glowStrength * 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2 + glowStrength * 0.4),
                      blurRadius: 18 + glowStrength * 18,
                      spreadRadius: 1 + glowStrength * 4,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: _CornerBrackets(glowStrength: glowStrength),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.75),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0, 0.35, 0.65, 1],
          ),
        ),
      ),
    );
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar({
    required this.isFlashOn,
    required this.canSwitch,
    required this.onFlashToggle,
    required this.onSwitchCamera,
  });

  final bool isFlashOn;
  final bool canSwitch;
  final VoidCallback onFlashToggle;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _GlassIconButton(
          icon: Icons.close,
          onTap: () => Navigator.of(context).pop(),
        ),
        Row(
          children: [
            _GlassIconButton(
              icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
              onTap: onFlashToggle,
            ),
            const SizedBox(width: 12),
            _GlassIconButton(
              icon: Icons.cameraswitch,
              onTap: canSwitch ? onSwitchCamera : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white),
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
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: isCapturing
              ? Colors.white.withOpacity(0.45)
              : Colors.white.withOpacity(0.15),
        ),
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets({required this.glowStrength});

  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerPainter(glowStrength: glowStrength),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.glowStrength});

  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7 + glowStrength * 0.25)
      ..strokeWidth = 4 + glowStrength * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    final radius = 18.0;

    // Top-left
    canvas.drawLine(
      Offset(0 + radius, 0),
      Offset(cornerLength + radius, 0),
      paint,
    );
    canvas.drawLine(
      Offset(0, 0 + radius),
      Offset(0, cornerLength + radius),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - radius, 0),
      Offset(size.width - cornerLength - radius, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0 + radius),
      Offset(size.width, cornerLength + radius),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0 + radius, size.height),
      Offset(cornerLength + radius, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height - radius),
      Offset(0, size.height - cornerLength - radius),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - radius, size.height),
      Offset(size.width - cornerLength - radius, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - radius),
      Offset(size.width, size.height - cornerLength - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.glowStrength != glowStrength;
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
