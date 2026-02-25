import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_error.dart';
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
  List<File> _galleryFiles = [];
  String? _resultText;
  String? _errorMessage;
  int? _lastDurationMs;
  RecognitionResult? _result;
  int _analysisToken = 0;
  int? _pendingToken;
  Future<void>? _pendingTask;
  RecognitionResult? _pendingResult;
  String? _pendingError;
  int? _pendingDurationMs;
  bool _awaitingConfirmation = false;

  DetectionStatus get status => _status;
  File? get imageFile => _imageFile;
  List<File> get galleryFiles => List.unmodifiable(_galleryFiles);
  String? get resultText => _resultText;
  String? get errorMessage => _errorMessage;
  int? get lastDurationMs => _lastDurationMs;
  RecognitionResult? get result => _result;
  String? get productName => _result?.productName ?? _resultText;
  String? get productionOrigin => _result?.productionOrigin;
  String? get hqCountry => _result?.hqCountry;
  String? get taxCountry => _result?.taxCountry;
  bool get isLoading => _status == DetectionStatus.analyzing;
  bool get hasImage => _imageFile != null;
  bool get isAwaitingConfirmation => _awaitingConfirmation;

  Future<void> pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    _imageFile = File(pickedFile.path);
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
    _result = null;
    _status = DetectionStatus.imageReady;
    notifyListeners();
  }

  Future<void> pickFromGallery() async {
    final pickedFiles = await _imagePicker.pickMultiImage();
    if (pickedFiles.isEmpty) return;
    _galleryFiles = pickedFiles.map((file) => File(file.path)).toList();
    _imageFile = _galleryFiles.first;
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
    _result = null;
    _status = DetectionStatus.imageReady;
    notifyListeners();
  }

  void setImage(File file) {
    _imageFile = file;
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
    _status = DetectionStatus.imageReady;
    notifyListeners();
  }

  Future<void> preAnalyzeImage() async {
    if (_imageFile == null) return;
    _analysisToken += 1;
    final token = _analysisToken;
    _pendingToken = token;
    _pendingResult = null;
    _pendingError = null;
    _pendingDurationMs = null;
    _awaitingConfirmation = true;
    _pendingTask = _runPreAnalysis(token, _imageFile!);
  }

  Future<void> _runPreAnalysis(int token, File imageFile) async {
    try {
      final stopwatch = Stopwatch()..start();
      final RecognitionResult result =
          await _recognitionApi.analyzeImage(imageFile);
      stopwatch.stop();
      if (token != _analysisToken) return;
      _pendingDurationMs = stopwatch.elapsedMilliseconds;
      _pendingResult = result;
    } catch (error) {
      if (token != _analysisToken) return;
      _pendingError = mapToUserMessage(error);
      if (kDebugMode) {
        debugPrint('Detection error: $error');
      }
    }
  }

  Future<void> confirmAnalysis() async {
    if (!_awaitingConfirmation) return;
    _awaitingConfirmation = false;
    final token = _pendingToken;
    final task = _pendingTask;
    if (token == null || task == null) return;

    if (_pendingResult != null || _pendingError != null) {
      _applyPending(token);
      return;
    }

    _status = DetectionStatus.analyzing;
    notifyListeners();
    await task;
    _applyPending(token);
  }

  void cancelPendingAnalysis() {
    _analysisToken += 1;
    _pendingToken = null;
    _pendingTask = null;
    _pendingResult = null;
    _pendingError = null;
    _pendingDurationMs = null;
    _awaitingConfirmation = false;
    reset();
  }

  void _applyPending(int token) {
    if (token != _analysisToken) return;
    _lastDurationMs = _pendingDurationMs;
    if (_pendingResult != null) {
      _result = _pendingResult;
      _resultText = _pendingResult?.message;
      _errorMessage = null;
      _status = DetectionStatus.success;
    } else {
      _errorMessage = _pendingError ?? 'Unable to analyze image.';
      _status = DetectionStatus.failure;
    }
    notifyListeners();
  }

  Future<void> analyzeImage() async {
    if (_imageFile == null) return;
    _analysisToken += 1;
    final token = _analysisToken;
    _status = DetectionStatus.analyzing;
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
  _result = null;
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();
      final RecognitionResult result =
          await _recognitionApi.analyzeImage(_imageFile!);
      stopwatch.stop();
      final durationMessage =
          'SendToServer duration: ${stopwatch.elapsedMilliseconds} ms';
      print(durationMessage);
      debugPrint(durationMessage);
      _lastDurationMs = stopwatch.elapsedMilliseconds;
      if (token != _analysisToken) return;
      _result = result;
      _resultText = result.message;
      _status = DetectionStatus.success;
    } catch (error) {
      if (token != _analysisToken) return;
      _errorMessage = mapToUserMessage(error);
      _status = DetectionStatus.failure;
      if (kDebugMode) {
        debugPrint('Detection error: $error');
      }
    }

    notifyListeners();
  }

  void reset() {
    _analysisToken += 1;
    _pendingToken = null;
    _pendingTask = null;
    _pendingResult = null;
    _pendingError = null;
    _pendingDurationMs = null;
    _awaitingConfirmation = false;
    _imageFile = null;
    _galleryFiles = [];
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
    _result = null;
    _status = DetectionStatus.idle;
    notifyListeners();
  }
}
