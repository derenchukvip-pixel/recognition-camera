import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/recognition/recognition_api_dio.dart';
import '../../core/consent/disclaimer_storage.dart';
import '../camera/camera_capture_screen.dart';
import 'detection_view_model.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  late final DetectionViewModel _viewModel;
  final DisclaimerStorage _disclaimerStorage = DisclaimerStorage();

  @override
  void initState() {
    super.initState();
    _viewModel = DetectionViewModel(recognitionApi: RecognitionApiDio());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerIfNeeded();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _showDisclaimerIfNeeded() async {
    final bool accepted = await _disclaimerStorage.isAccepted();
    if (!mounted || accepted) return;

    final bool? userAccepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Important notice'),
          content: const Text(
            'This app uses real-world data and models that may contain '
            'inaccuracies. Use the results as reference information and '
            'verify important data independently.\n\n'
            'By tapping “Agree”, you confirm that you understand these '
            'limitations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Disagree'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Agree'),
            ),
          ],
        );
      },
    );

    if (userAccepted == true) {
      await _disclaimerStorage.setAccepted(true);
      return;
    }

    await _disclaimerStorage.setAccepted(false);
    if (!mounted) return;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const _DetectionScreenView(),
    );
  }
}

class _DetectionScreenView extends StatelessWidget {
  const _DetectionScreenView();

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetectionViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Recognition Camera')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (viewModel.imageFile != null)
                Image.file(viewModel.imageFile!, height: 200),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: viewModel.isLoading
                    ? null
                    : () => _openCamera(context, viewModel),
                child: const Text('Add photo'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: viewModel.hasImage && !viewModel.isLoading
                    ? viewModel.analyzeImage
                    : null,
                child: const Text('Send photo to server'),
              ),
              const SizedBox(height: 24),
              if (viewModel.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: _LoadingRow(),
                ),
              if (!viewModel.isLoading && viewModel.resultText != null)
                ResultTextCard(text: viewModel.resultText!),
              if (!viewModel.isLoading && viewModel.errorMessage != null)
                ResultTextCard(
                  text: viewModel.errorMessage!,
                  textColor: Colors.red,
                ),
            ],
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
        SizedBox(
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
