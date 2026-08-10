import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/models/detection.dart';
import 'object_detector.dart';
import 'yolo_postprocess.dart';

/// YOLOv8n through TensorFlow Lite, running on the phone.
///
/// What it is for, stated precisely, because the previous description was
/// wrong in a way that mattered: this detects **object categories** from the
/// 80-class COCO set. It can report that there is a bottle in the frame. It
/// cannot report which bottle, and it never could — COCO has no notion of a
/// brand or a product. Identifying the product is the cloud path's job.
///
/// So the honest use is the one it is put to: an offline check, before
/// anything is uploaded, of whether the photograph contains a recognisable
/// object at all. That catches a blurred or badly-framed shot at the moment
/// the user can still retake it, costs no network, and sends nothing anywhere.
///
/// The interpreter is loaded once and kept. Loading it takes long enough to be
/// visible, and the frame check runs on every capture.
class OnDeviceAIService implements ObjectDetector {
  Interpreter? _interpreter;
  List<String>? _labels;
  Future<void>? _loading;

  static const int _inputSize = 640;

  Future<void> _ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/yolov8/yolov8n_float32.tflite',
    );
    final raw = await rootBundle.loadString('assets/models/yolov8/labels.txt');
    _labels = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Detection>> detect(File image) async {
    await _ensureLoaded();

    final decoded = img.decodeImage(await image.readAsBytes());
    if (decoded == null) return const [];

    final interpreter = _interpreter!;
    final outputShape = interpreter.getOutputTensor(0).shape;
    final output = List.filled(
      outputShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputShape);

    interpreter.run(
      _inputTensor(decoded).reshape([1, _inputSize, _inputSize, 3]),
      output,
    );

    final channels = (output[0] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();

    final decodedBoxes = YoloPostprocess.decode(
      [channels],
      labels: _labels!,
      sourceWidth: decoded.width,
      sourceHeight: decoded.height,
      inputSize: _inputSize,
    );

    return YoloPostprocess.bestPerLabel(
      YoloPostprocess.nonMaximumSuppression(decodedBoxes),
    );
  }

  /// Resize to 640×640, normalise to 0..1, and write the channels in **BGR**.
  ///
  /// The channel order is not a preference. It matches how the bundled model
  /// was exported, and getting it wrong does not fail loudly — it silently
  /// degrades every prediction, which is the worst way for a mistake to
  /// behave.
  Float32List _inputTensor(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _inputSize,
      height: _inputSize,
    );
    final input = Float32List(_inputSize * _inputSize * 3);

    var i = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[i++] = pixel.b / 255.0;
        input[i++] = pixel.g / 255.0;
        input[i++] = pixel.r / 255.0;
      }
    }
    return input;
  }

  void dispose() {
    try {
      _interpreter?.close();
    } catch (error) {
      if (kDebugMode) debugPrint('Interpreter close failed: $error');
    }
    _interpreter = null;
    _loading = null;
  }
}
