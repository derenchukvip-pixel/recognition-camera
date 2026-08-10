import 'dart:math' as math;

import '../../domain/models/detection.dart';

/// Turning a YOLOv8 output tensor into a list of objects.
///
/// This is the actual work of running a detector, and it is separated from the
/// interpreter so it can be tested without a 6 MB model file and a native
/// delegate. The README has claimed for two releases that the post-processing
/// is "written out, not imported"; until it was pulled out here, none of it was
/// covered, and it contained a real bug — see [intersectionOverUnion].
///
/// The model emits `[1, 84, 8400]`: 8400 candidate boxes, each with 80 COCO
/// class scores followed by four geometry values, laid out transposed — class
/// first, box second. Making sense of that is four steps: argmax the scores,
/// drop everything under the confidence floor, convert `[cx, cy, w, h]` to a
/// corner and rescale it out of the 640×640 letterbox, then collapse the dozen
/// overlapping boxes the model emits per object.
class YoloPostprocess {
  const YoloPostprocess._();

  /// Tuned for this model. Both are single constants on purpose: they are the
  /// two numbers anyone swapping the model has to revisit.
  static const double confidenceThreshold = 0.5;
  static const double iouThreshold = 0.45;

  /// [output] is indexed `[0][channel][box]`, matching the tensor layout.
  static List<Detection> decode(
    List<List<List<double>>> output, {
    required List<String> labels,
    required int sourceWidth,
    required int sourceHeight,
    int inputSize = 640,
    double confidence = confidenceThreshold,
  }) {
    final channels = output[0];
    final numClasses = math.min(labels.length, channels.length - 4);
    final numBoxes = channels[0].length;
    final detections = <Detection>[];

    for (var b = 0; b < numBoxes; b++) {
      var bestClass = 0;
      var bestScore = channels[0][b];
      for (var c = 1; c < numClasses; c++) {
        final score = channels[c][b];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }
      if (bestScore <= confidence) continue;

      final cx = channels[numClasses][b];
      final cy = channels[numClasses + 1][b];
      final w = channels[numClasses + 2][b];
      final h = channels[numClasses + 3][b];

      final scaleX = sourceWidth / inputSize;
      final scaleY = sourceHeight / inputSize;

      detections.add(
        Detection(
          label: labels[bestClass],
          confidence: bestScore,
          x: (cx - w / 2) * scaleX,
          y: (cy - h / 2) * scaleY,
          width: w * scaleX,
          height: h * scaleY,
        ),
      );
    }

    return detections;
  }

  /// Collapses overlapping boxes of the same class, keeping the most confident.
  ///
  /// Same-class only: a bottle box and a cup box can overlap heavily and still
  /// both be right, and suppressing across classes would delete one of them.
  static List<Detection> nonMaximumSuppression(
    List<Detection> detections, {
    double threshold = iouThreshold,
  }) {
    final ordered = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    final suppressed = List<bool>.filled(ordered.length, false);

    for (var i = 0; i < ordered.length; i++) {
      if (suppressed[i]) continue;
      kept.add(ordered[i]);
      for (var j = i + 1; j < ordered.length; j++) {
        if (suppressed[j]) continue;
        if (ordered[i].label != ordered[j].label) continue;
        if (intersectionOverUnion(ordered[i], ordered[j]) > threshold) {
          suppressed[j] = true;
        }
      }
    }

    return kept;
  }

  /// Overlap of two boxes, 0 to 1.
  ///
  /// The previous implementation read `[x, y, w, h]` as if `x, y` were the
  /// box's centre and subtracted half the width again — but the decode step
  /// had already converted the centre to a corner. Two boxes were therefore
  /// each shifted by half of *their own* size before being compared, so the
  /// overlap of two boxes of different sizes was computed between two
  /// rectangles that were not where either box was. Same-size boxes cancelled
  /// the error, which is why it survived: the duplicates NMS usually sees are
  /// near-identical.
  static double intersectionOverUnion(Detection a, Detection b) {
    final left = math.max(a.x, b.x);
    final top = math.max(a.y, b.y);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);

    final overlap = math.max(0.0, right - left) * math.max(0.0, bottom - top);
    if (overlap <= 0) return 0;

    return overlap / (a.area + b.area - overlap);
  }

  /// The best detection per label, most confident first.
  static List<Detection> bestPerLabel(List<Detection> detections) {
    final best = <String, Detection>{};
    for (final detection in detections) {
      final current = best[detection.label];
      if (current == null || detection.confidence > current.confidence) {
        best[detection.label] = detection;
      }
    }
    return best.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }
}
