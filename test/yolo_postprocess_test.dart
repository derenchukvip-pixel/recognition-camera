import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/data/ai/yolo_postprocess.dart';
import 'package:recognition_camera/domain/models/detection.dart';

Detection _box({
  String label = 'bottle',
  double confidence = 0.9,
  double x = 0,
  double y = 0,
  double width = 100,
  double height = 100,
}) =>
    Detection(
      label: label,
      confidence: confidence,
      x: x,
      y: y,
      width: width,
      height: height,
    );

/// Builds a `[1, 84, N]` tensor the way the model emits one: class scores
/// first, then the four geometry channels, indexed `[channel][box]`.
List<List<List<double>>> _tensor(
  List<({int classIndex, double score, List<double> box})> boxes, {
  int numClasses = 3,
}) {
  final channels = List.generate(
    numClasses + 4,
    (_) => List<double>.filled(boxes.length, 0),
  );
  for (var b = 0; b < boxes.length; b++) {
    channels[boxes[b].classIndex][b] = boxes[b].score;
    for (var i = 0; i < 4; i++) {
      channels[numClasses + i][b] = boxes[b].box[i];
    }
  }
  return [channels];
}

const _labels = ['person', 'bottle', 'cup'];

void main() {
  group('intersection over union', () {
    test('identical boxes overlap completely', () {
      expect(
        YoloPostprocess.intersectionOverUnion(_box(), _box()),
        closeTo(1.0, 1e-9),
      );
    });

    test('disjoint boxes do not overlap', () {
      expect(
        YoloPostprocess.intersectionOverUnion(_box(), _box(x: 500)),
        0,
      );
    });

    test('half-overlapping boxes score one third', () {
      // Two 100x100 boxes offset by 50 share 50x100; union is 15000.
      expect(
        YoloPostprocess.intersectionOverUnion(_box(), _box(x: 50)),
        closeTo(5000 / 15000, 1e-9),
      );
    });

    test('a box fully inside a larger one', () {
      // The regression case. The previous implementation read x,y as the
      // centre and shifted each box by half of its own size before
      // comparing — so boxes of different sizes were measured against
      // rectangles neither of them occupied. Equal-size boxes cancelled the
      // error, which is why it survived: NMS mostly sees near-duplicates.
      final outer = _box(width: 100, height: 100);
      final inner = _box(x: 25, y: 25, width: 50, height: 50);

      expect(
        YoloPostprocess.intersectionOverUnion(outer, inner),
        closeTo(2500 / 10000, 1e-9),
      );
    });
  });

  group('non-maximum suppression', () {
    test('collapses duplicates of the same object, keeping the best', () {
      final kept = YoloPostprocess.nonMaximumSuppression([
        _box(confidence: 0.7, x: 4),
        _box(confidence: 0.95),
        _box(confidence: 0.6, x: 8),
      ]);

      expect(kept.length, 1);
      expect(kept.single.confidence, 0.95);
    });

    test('keeps two objects that genuinely overlap', () {
      // A cup in front of a bottle is two answers, not one. Suppressing
      // across classes would delete a correct detection.
      final kept = YoloPostprocess.nonMaximumSuppression([
        _box(label: 'bottle', confidence: 0.9),
        _box(label: 'cup', confidence: 0.85, x: 5),
      ]);

      expect(kept.length, 2);
    });

    test('keeps two of the same class that are far apart', () {
      final kept = YoloPostprocess.nonMaximumSuppression([
        _box(confidence: 0.9),
        _box(confidence: 0.8, x: 400),
      ]);

      expect(kept.length, 2);
    });
  });

  group('decoding the tensor', () {
    test('argmax picks the class and the threshold drops the rest', () {
      final detections = YoloPostprocess.decode(
        _tensor([
          (classIndex: 1, score: 0.91, box: [320, 320, 64, 64]),
          (classIndex: 2, score: 0.10, box: [10, 10, 8, 8]),
        ]),
        labels: _labels,
        sourceWidth: 640,
        sourceHeight: 640,
      );

      expect(detections.length, 1);
      expect(detections.single.label, 'bottle');
      expect(detections.single.confidence, closeTo(0.91, 1e-9));
    });

    test('centre-and-size becomes a corner, rescaled to the source image', () {
      // 640-square model input, 1280x960 source: x doubles, y scales by 1.5.
      final detections = YoloPostprocess.decode(
        _tensor([
          (classIndex: 1, score: 0.9, box: [320, 320, 64, 64]),
        ]),
        labels: _labels,
        sourceWidth: 1280,
        sourceHeight: 960,
      );

      final box = detections.single;
      expect(box.x, closeTo((320 - 32) * 2, 1e-9));
      expect(box.y, closeTo((320 - 32) * 1.5, 1e-9));
      expect(box.width, closeTo(128, 1e-9));
      expect(box.height, closeTo(96, 1e-9));
    });

    test('an empty frame decodes to nothing rather than to a guess', () {
      final detections = YoloPostprocess.decode(
        _tensor([
          (classIndex: 0, score: 0.2, box: [1, 1, 1, 1]),
        ]),
        labels: _labels,
        sourceWidth: 640,
        sourceHeight: 640,
      );

      expect(detections, isEmpty);
    });
  });

  group('best per label', () {
    test('one entry per label, most confident first', () {
      final best = YoloPostprocess.bestPerLabel([
        _box(label: 'bottle', confidence: 0.6),
        _box(label: 'cup', confidence: 0.95),
        _box(label: 'bottle', confidence: 0.8),
      ]);

      expect(best.map((d) => d.label), ['cup', 'bottle']);
      expect(best.last.confidence, 0.8);
    });
  });

  group('the sentence the user reads', () {
    test('one object', () {
      expect(framedObjectsSummary([_box()]), 'Bottle in frame');
    });

    test('two objects', () {
      expect(
        framedObjectsSummary([_box(), _box(label: 'cup')]),
        'Bottle and cup in frame',
      );
    });

    test('more than the limit are dropped, not summarised as "and more"', () {
      expect(
        framedObjectsSummary([
          _box(label: 'bottle'),
          _box(label: 'cup'),
          _box(label: 'book'),
          _box(label: 'laptop'),
        ]),
        'Bottle, cup and book in frame',
      );
    });

    test('nothing found returns null so the caller can say something else', () {
      expect(framedObjectsSummary(const []), isNull);
    });
  });
}
