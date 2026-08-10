import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_error.dart';
import '../../data/ai/object_detector.dart';
import '../../data/recognition/recognition_api.dart';
import '../../domain/models/detection.dart';
import '../../domain/models/recognition_result.dart';

enum DetectionStatus { idle, imageReady, analyzing, success, failure }

/// The result of the offline look at the photograph, before anything is sent.
enum FrameCheck {
  /// No photo yet, or no detector wired in.
  none,

  /// Running on the device.
  running,

  /// At least one object recognised. See [DetectionViewModel.frameSummary].
  found,

  /// The model ran and recognised nothing. An answer, not a failure.
  empty,

  /// The detector could not run at all. Says nothing about the photo, so the
  /// UI stays quiet rather than blaming the user's framing for a model that
  /// failed to load.
  unavailable,
}

class DetectionViewModel extends ChangeNotifier {
  DetectionViewModel({
    required RecognitionApi recognitionApi,
    ObjectDetector? objectDetector,
    ImagePicker? imagePicker,
  })  : _recognitionApi = recognitionApi,
        _objectDetector = objectDetector,
        _imagePicker = imagePicker ?? ImagePicker();

  final RecognitionApi _recognitionApi;

  /// Null disables the frame check entirely, which is what the tests that do
  /// not care about it pass.
  final ObjectDetector? _objectDetector;

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
  FrameCheck _frameCheck = FrameCheck.none;
  String? _frameSummary;
  int _frameToken = 0;

  DetectionStatus get status => _status;
  File? get imageFile => _imageFile;
  List<File> get galleryFiles => List.unmodifiable(_galleryFiles);
  String? get resultText => _resultText;
  String? get errorMessage => _errorMessage;
  int? get lastDurationMs => _lastDurationMs;
  RecognitionResult? get result => _result;
  String? get productName => _result?.productName;
  String? get productionOrigin => _result?.productionOrigin;
  String? get companyName => _result?.companyName;
  String? get hqCountry => _result?.hqCountry;
  String? get taxCountry => _result?.taxCountry;
  bool get isLoading => _status == DetectionStatus.analyzing;
  bool get hasImage => _imageFile != null;
  bool get isAwaitingConfirmation => _awaitingConfirmation;

  FrameCheck get frameCheck => _frameCheck;

  /// "Bottle in frame", or null. A COCO object category, never a product —
  /// the screen that shows it has to say so.
  String? get frameSummary => _frameSummary;

  /// Looks at the photograph on the device, before anything is uploaded.
  ///
  /// Runs alongside the cloud pre-analysis rather than gating it: the point is
  /// to give the user something to judge the photo by while the upload is
  /// already in flight, not to add a step. A detector failure is swallowed
  /// into [FrameCheck.unavailable] for the same reason — the frame check is an
  /// aid, and an aid that can block a scan is worse than no aid.
  Future<void> _runFrameCheck(File image) async {
    final detector = _objectDetector;
    if (detector == null) return;

    _frameToken += 1;
    final token = _frameToken;
    _frameCheck = FrameCheck.running;
    _frameSummary = null;
    notifyListeners();

    FrameCheck outcome;
    String? summary;
    try {
      final detections = await detector.detect(image);
      summary = framedObjectsSummary(detections);
      outcome = summary == null ? FrameCheck.empty : FrameCheck.found;
    } catch (error) {
      outcome = FrameCheck.unavailable;
      if (kDebugMode) debugPrint('Frame check failed: $error');
    }

    // A newer photo has been taken since this started; its own check is the
    // one that counts.
    if (token != _frameToken) return;
    _frameCheck = outcome;
    _frameSummary = summary;
    notifyListeners();
  }

  void _resetFrameCheck() {
    _frameToken += 1;
    _frameCheck = FrameCheck.none;
    _frameSummary = null;
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
    _resetFrameCheck();
    notifyListeners();
    unawaited(_runFrameCheck(_imageFile!));
  }

  void setImage(File file) {
    _imageFile = file;
    _resultText = null;
    _errorMessage = null;
    _lastDurationMs = null;
    _status = DetectionStatus.imageReady;
    _resetFrameCheck();
    notifyListeners();
    unawaited(_runFrameCheck(file));
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
    _resetFrameCheck();
    notifyListeners();
  }
}
