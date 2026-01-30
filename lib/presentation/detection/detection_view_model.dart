import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/recognition/recognition_api.dart';
import '../../domain/models/recognition_result.dart';

enum DetectionStatus { idle, imageReady, analyzing, success, failure }

class DetectionViewModel extends ChangeNotifier {
  DetectionViewModel({
    required RecognitionApi recognitionApi,
    ImagePicker? imagePicker,
  })  : _recognitionApi = recognitionApi,
        _imagePicker = imagePicker ?? ImagePicker();

  final RecognitionApi _recognitionApi;
  final ImagePicker _imagePicker;

  DetectionStatus _status = DetectionStatus.idle;
  File? _imageFile;
  String? _resultText;
  String? _errorMessage;

  DetectionStatus get status => _status;
  File? get imageFile => _imageFile;
  String? get resultText => _resultText;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DetectionStatus.analyzing;
  bool get hasImage => _imageFile != null;

  Future<void> pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    _imageFile = File(pickedFile.path);
    _resultText = null;
    _errorMessage = null;
    _status = DetectionStatus.imageReady;
    notifyListeners();
  }

  void setImage(File file) {
    _imageFile = file;
    _resultText = null;
    _errorMessage = null;
    _status = DetectionStatus.imageReady;
    notifyListeners();
  }

  Future<void> analyzeImage() async {
    if (_imageFile == null) return;
    _status = DetectionStatus.analyzing;
    _resultText = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final RecognitionResult result =
          await _recognitionApi.analyzeImage(_imageFile!);
      _resultText = result.message;
      _status = DetectionStatus.success;
    } catch (error) {
      _errorMessage = 'Failed to analyze image: ${error.toString()}';
      _status = DetectionStatus.failure;
      if (kDebugMode) {
        debugPrint('Detection error: $error');
      }
    }

    notifyListeners();
  }

  void reset() {
    _imageFile = null;
    _resultText = null;
    _errorMessage = null;
    _status = DetectionStatus.idle;
    notifyListeners();
  }
}
