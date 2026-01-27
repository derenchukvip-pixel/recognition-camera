

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Removed unused import
// import 'package:tflite_flutter/tflite_flutter.dart';

class OnDeviceAIService {
  /// Оценка страны производства по типу объекта и/или баркоду
  String estimateProductionInfo({String? objectLabel, String? barcode}) {
    // По баркоду
    if (barcode != null && barcode.isNotEmpty) {
      if (barcode.startsWith('50')) {
        return "40% UK, 40% China, 20% Other";
      }
      if (barcode.startsWith('00') || barcode.startsWith('01') || barcode.startsWith('02') || barcode.startsWith('03') || barcode.startsWith('04') || barcode.startsWith('05') || barcode.startsWith('06') || barcode.startsWith('07') || barcode.startsWith('08') || barcode.startsWith('09')) {
        return "60% USA/Canada, 30% China, 10% Mexico";
      }
      if (barcode.startsWith('690') || barcode.startsWith('691') || barcode.startsWith('692') || barcode.startsWith('693') || barcode.startsWith('694') || barcode.startsWith('695') || barcode.startsWith('696') || barcode.startsWith('697') || barcode.startsWith('698') || barcode.startsWith('699')) {
        return "70% China, 20% Other Asian countries, 10% Other";
      }
      // Можно добавить другие правила по префиксам
    }
    // По типу объекта
    if (objectLabel != null && objectLabel.isNotEmpty) {
      final label = objectLabel.toLowerCase();
      if (label.contains("laptop")) {
        return "70% China, 20% USA, 10% Other";
      }
      if (label.contains("cup")) {
        return "60% China, 30% Europe, 10% Other";
      }
      if (label.contains("bottle")) {
        return "80% China, 10% Europe, 10% Other";
      }
      if (label.contains("apple")) {
        return "50% China, 30% Poland, 20% Other";
      }
      if (label.contains("car")) {
        return "40% Germany, 30% Japan, 30% Other";
      }
      // ...добавить свои правила
    }
    // Если ничего не найдено
    return "50% China, 30% Other Asia, 20% Other";
  }
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
  _interpreter = await Interpreter.fromAsset('assets/models/yolov8/yolov8n_float32.tflite');
    final labelsData = await rootBundle.loadString('assets/models/yolov8/labels.txt');
    _labels = labelsData.split('\n');
    _initialized = true;
  }

  Future<String> processImage(File imageFile) async {
    await init();
    final imageBytes = await imageFile.readAsBytes();
    print('[AI] Начало processImage');
    final image = img.decodeImage(imageBytes);
    print('[AI] Модель и labels инициализированы');
    if (image == null) return 'Could not decode image';

    // 1. Resize to 640x640

    print('[AI] Исходное изображение: ${image.width}x${image.height}');
    final resized = img.copyResize(image, width: 640, height: 640);

    // 2. Получить параметры inputTensor
    print('[AI] Изображение ресайзнуто до 640x640');
    final inputTensor = _interpreter!.getInputTensor(0);
    print('Input tensor type: ${inputTensor.type}');

    print('[AI] Input tensor type: ${inputTensor.type}, shape: ${inputTensor.shape}');
    // 3. Преобразовать изображение в Float32List (0..1)
    final input = Float32List(640 * 640 * 3);
    int i = 0;
    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        final pixel = resized.getPixel(x, y);
        input[i++] = (pixel.b / 255.0); // Blue
        input[i++] = (pixel.g / 255.0); // Green
        input[i++] = (pixel.r / 255.0); // Red
      }
    }

    print('[AI] Препроцессинг завершён, input shape: ${input.length}');
    // 4. Prepare input shape [1, 640, 640, 3]
    final inputShape = [1, 640, 640, 3];
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outScale = outputTensor.params.scale;
    final outZeroPoint = outputTensor.params.zeroPoint;
    final output = List.filled(outputShape.reduce((a, b) => a * b), 0).reshape(outputShape);

    print('[AI] Output tensor type: ${outputTensor.type}, shape: $outputShape');
    // 5. Run inference
    _interpreter!.run(input.reshape(inputShape), output);
    print('[AI] Запуск инференса...');

    print('[AI] Инференс завершён');
    // 6. YOLOv8 output: [1, num_classes + 4, num_boxes] (e.g., [1, 84, 8400])
    // Postprocess: find boxes with confidence > threshold
    final confThreshold = 0.5;
    final iouThreshold = 0.45;
    final numClasses = 80; // COCO
    final numBoxes = outputShape.last;
    final detections = <Map<String, dynamic>>[];

    print('[AI] Постпроцессинг: numClasses=$numClasses, numBoxes=$numBoxes');
    // Собираем все боксы с confidence > threshold
    for (int b = 0; b < numBoxes; b++) {
      // scores: вероятности классов
      final scores = List<double>.generate(numClasses, (c) => output[0][c][b] as double);
      final classIdx = scores.indexOf(scores.reduce((a, b) => a > b ? a : b));
      final confidence = scores[classIdx];
      if (b < 3) {
        print('Box #$b scores: ' + scores.map((v) => v.toStringAsFixed(3)).take(10).join(', '));
        final debugBoxRaw = List.generate(4, (i) => (output[0][numClasses + i][b] as double));
        print('Box #$b raw box: ' + debugBoxRaw.join(', '));
      }
      print('[AI] Box #$b: classIdx=$classIdx, confidence=$confidence');
      // Логируем boxRaw для всех боксов с высоким confidence
      final boxRaw = List.generate(4, (i) => (output[0][numClasses + i][b] as double));
      if (confidence > confThreshold) {
        print('[AI] Box #$b boxRaw: $boxRaw');
        print('[AI] image.width=${image.width}, image.height=${image.height}');
      }
      if (confidence > confThreshold && classIdx >= 0 && classIdx < numClasses && classIdx < _labels!.length) {
        // Преобразуем [cx, cy, w, h] в [x, y, w, h] (x, y — левый верхний угол)
        final cx = boxRaw[0];
        final cy = boxRaw[1];
        final w = boxRaw[2];
        final h = boxRaw[3];
        final x = cx - w / 2;
        final y = cy - h / 2;
        // Масштабируем координаты в размер исходного изображения
        final bbox = <double>[
          x * image.width / 640.0,
          y * image.height / 640.0,
          w * image.width / 640.0,
          h * image.height / 640.0,
        ];
        print('[AI] Box #$b: bbox=${bbox.map((v) => v.toStringAsFixed(1)).toList()} label=${_labels![classIdx]}');
        detections.add(<String, dynamic>{
          'classIdx': classIdx,
          'label': _labels![classIdx],
          'confidence': confidence,
          'box': bbox, // [x, y, w, h] в пикселях
        });
      }
    }

    print('[AI] Всего детекций после threshold: ${detections.length}');
    // NMS: оставляем только уникальные объекты
    List<Map<String, dynamic>> nmsDetections = _nms(detections, iouThreshold);

    print('[AI] После NMS: ${nmsDetections.length}');
    if (nmsDetections.isEmpty) return 'No objects detected.';

    // Группируем по label и оставляем только максимальный confidence для каждого класса
    final Map<String, Map<String, dynamic>> bestByLabel = {};
    for (final det in nmsDetections) {
      final label = det['label'] as String;
      if (!bestByLabel.containsKey(label) || det['confidence'] > bestByLabel[label]!['confidence']) {
        bestByLabel[label] = det;
      }
    }
    // Сортируем по confidence и берём топ-3
    print('[AI] Уникальных классов: ${bestByLabel.length}');
    final top3 = bestByLabel.values.toList()
      ..sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    final result = top3.take(3).map((det) {
      final box = det['box'] as List<double>;
      return 'Detected: ${det['label']} (confidence: ${(det['confidence'] * 100).toStringAsFixed(1)}%) at [x: ${box[0].toStringAsFixed(1)}, y: ${box[1].toStringAsFixed(1)}, w: ${box[2].toStringAsFixed(1)}, h: ${box[3].toStringAsFixed(1)}]';
    }).join('\n');
    return result;
    print('[AI] Финальный результат:\n$result');
  }

  // Non-Maximum Suppression (NMS)
  List<Map<String, dynamic>> _nms(List<Map<String, dynamic>> detections, double iouThreshold) {
    detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    final selected = <Map<String, dynamic>>[];
    final used = List<bool>.filled(detections.length, false);
    for (int i = 0; i < detections.length; i++) {
      if (used[i]) continue;
      final detA = detections[i];
      selected.add(detA);
      for (int j = i + 1; j < detections.length; j++) {
        if (used[j]) continue;
        final detB = detections[j];
        if (detA['classIdx'] == detB['classIdx'] && _iou(detA['box'], detB['box']) > iouThreshold) {
          used[j] = true;
        }
      }
    }
    return selected;
  }

  // Intersection over Union (IoU) для двух боксов [x, y, w, h]
  double _iou(List<double> boxA, List<double> boxB) {
    final xA = boxA[0] - boxA[2] / 2;
    final yA = boxA[1] - boxA[3] / 2;
    final xB = boxB[0] - boxB[2] / 2;
    final yB = boxB[1] - boxB[3] / 2;
    final xA2 = boxA[0] + boxA[2] / 2;
    final yA2 = boxA[1] + boxA[3] / 2;
    final xB2 = boxB[0] + boxB[2] / 2;
    final yB2 = boxB[1] + boxB[3] / 2;
    final interX1 = xA > xB ? xA : xB;
    final interY1 = yA > yB ? yA : yB;
    final interX2 = xA2 < xB2 ? xA2 : xB2;
    final interY2 = yA2 < yB2 ? yA2 : yB2;
    final interArea = (interX2 - interX1).clamp(0, double.infinity) * (interY2 - interY1).clamp(0, double.infinity);
    final boxAArea = (xA2 - xA) * (yA2 - yA);
    final boxBArea = (xB2 - xB) * (yB2 - yB);
    return interArea / (boxAArea + boxBArea - interArea + 1e-6);
  }
}
