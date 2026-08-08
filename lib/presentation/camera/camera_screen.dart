import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/error/app_error.dart';
import '../../data/ai/on_device_ai_service.dart';
import '../../data/open_food_facts/open_food_facts_api.dart';
import '../barcode/barcode_scanner_screen.dart';
import '../product/product_info_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? _errorMessage;
  final OnDeviceAIService _aiService = OnDeviceAIService();
  final OpenFoodFactsApi _openFoodFactsApi = OpenFoodFactsApi();
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.max,
          enableAudio: false,
        );
        await _controller!.initialize();
        setState(() {
          _isInitialized = true;
        });
      } else {
        setState(() {
          _errorMessage = 'No cameras found on this device.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    if (_controller != null && _controller!.value.isInitialized) {
      final image = await _controller!.takePicture();
      _showResultDialog(image);
    }
  }

  void _showResultDialog(XFile image) {
    showDialog(
      context: context,
      barrierDismissible: false,
      // Named `dialogContext` rather than `context`: shadowing the State's
      // context here is what made the code below reach for a context that had
      // already been popped.
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Result'),
          content: Image.file(File(image.path), fit: BoxFit.cover),
          actions: [
            TextButton(
              onPressed: () async {
                // Captured before the first await. Inference takes seconds, and
                // by the time it returns this dialog is gone and the user may
                // have left the screen entirely.
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(dialogContext).pop();

                final result = await _aiService.processImage(File(image.path));
                debugPrint('AI Result: $result');
                if (!mounted) return;

                await showDialog(
                  // The State's context, not the popped dialog's.
                  context: context,
                  builder: (resultContext) => AlertDialog(
                    title: const Text('AI Result'),
                    content: Text(result.isNotEmpty ? result : 'No result'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(resultContext).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );

                // Surface a SnackBar when the model returns nothing
                if (result.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('No object recognised.')),
                  );
                }
              },
              child: const Text('Use'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Retake'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isInitialized
                ? CameraPreview(_controller!)
                : Container(color: Colors.black),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: FloatingActionButton(
                onPressed: _isInitialized ? _captureImage : null,
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take photo'),
                  onPressed: _isInitialized ? _captureImage : null,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan barcode'),
                  onPressed: () async {
                    // Both are resolved from the tree once, up front. After an
                    // await the element this context points at may be gone, and
                    // `Navigator.of` would then throw instead of navigating.
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    final barcode = await navigator.push<String>(
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    );
                    if (barcode == null) return;
                    if (!mounted) return;

                    showDialog(
                      context: this.context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      final product =
                          await _openFoodFactsApi.fetchProduct(barcode);
                      navigator.pop(); // remove loading dialog
                      if (product != null) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => ProductInfoScreen(product: product),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Product not found: $barcode'),
                          ),
                        );
                      }
                    } catch (error) {
                      navigator.pop(); // remove loading dialog
                      messenger.showSnackBar(
                        SnackBar(content: Text(mapToUserMessage(error))),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black87,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
