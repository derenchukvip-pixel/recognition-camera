import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/data/ai/object_detector.dart';
import 'package:recognition_camera/data/recognition/recognition_api.dart';
import 'package:recognition_camera/domain/models/detection.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/presentation/detection/detection_view_model.dart';
import 'package:recognition_camera/presentation/detection/widgets/confirm_photo_view.dart';

class _FakeApi implements RecognitionApi {
  @override
  Future<RecognitionResult> analyzeImage(File imageFile) async =>
      const RecognitionResult(message: 'ok', rawResponse: 'ok');
}

/// The detector, held open so the test controls when it answers. That is the
/// only way to observe the running state, which is most of what the user sees.
class _FakeDetector implements ObjectDetector {
  final completer = Completer<List<Detection>>();
  int calls = 0;

  @override
  Future<List<Detection>> detect(File image) {
    calls += 1;
    return completer.future;
  }
}

class _BrokenDetector implements ObjectDetector {
  @override
  Future<List<Detection>> detect(File image) async =>
      throw StateError('model failed to load');
}

Detection _bottle() => const Detection(
      label: 'bottle',
      confidence: 0.92,
      x: 0,
      y: 0,
      width: 10,
      height: 10,
    );

DetectionViewModel _viewModel(ObjectDetector? detector) => DetectionViewModel(
      recognitionApi: _FakeApi(),
      objectDetector: detector,
    );

void main() {
  group('the frame check', () {
    test('runs as soon as a photo is taken, before anything is uploaded', () {
      final detector = _FakeDetector();
      final viewModel = _viewModel(detector);

      viewModel.setImage(File('shelf.jpg'));

      expect(detector.calls, 1);
      expect(viewModel.frameCheck, FrameCheck.running);
      expect(viewModel.frameSummary, isNull);
    });

    test('reports what it found', () async {
      final detector = _FakeDetector();
      final viewModel = _viewModel(detector);
      viewModel.setImage(File('bottle.jpg'));

      detector.completer.complete([_bottle()]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.frameCheck, FrameCheck.found);
      expect(viewModel.frameSummary, 'Bottle in frame');
    });

    test('an empty frame is an answer, not a failure', () async {
      final detector = _FakeDetector();
      final viewModel = _viewModel(detector);
      viewModel.setImage(File('wall.jpg'));

      detector.completer.complete(const []);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.frameCheck, FrameCheck.empty);
      expect(viewModel.frameSummary, isNull);
    });

    test('a detector that cannot run never blames the photo', () async {
      final viewModel = _viewModel(_BrokenDetector());
      viewModel.setImage(File('bottle.jpg'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.frameCheck, FrameCheck.unavailable);
    });

    test('a stale result cannot overwrite a newer photo', () async {
      final first = _FakeDetector();
      final viewModel = _viewModel(first);
      viewModel.setImage(File('first.jpg'));

      // Retaken before the first check came back.
      viewModel.reset();
      first.completer.complete([_bottle()]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.frameCheck, FrameCheck.none);
      expect(viewModel.frameSummary, isNull);
    });

    test('no detector wired in leaves the feature silent', () {
      final viewModel = _viewModel(null);
      viewModel.setImage(File('bottle.jpg'));

      expect(viewModel.frameCheck, FrameCheck.none);
    });
  });

  group('what the confirm screen says about it', () {
    Future<void> pump(WidgetTester tester, FrameCheck check, String? summary) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrameCheckNote(check: check, summary: summary),
          ),
        ),
      );
    }

    testWidgets('a found object is never presented as the product',
        (tester) async {
      await pump(tester, FrameCheck.found, 'Bottle in frame');

      expect(find.text('Bottle in frame'), findsOneWidget);
      // The load-bearing sentence. The detector knows COCO categories and
      // cannot name a product; without this line "Bottle in frame" reads as
      // an identification.
      expect(
        find.textContaining('An object category, not the product'),
        findsOneWidget,
      );
    });

    testWidgets('an empty frame suggests a fix and does not block the scan',
        (tester) async {
      await pump(tester, FrameCheck.empty, null);

      expect(find.text('No object recognised'), findsOneWidget);
      expect(find.textContaining('You can still analyse it'), findsOneWidget);
    });

    testWidgets('while running it says where the work is happening',
        (tester) async {
      await pump(tester, FrameCheck.running, null);

      expect(find.text('Checking the photo'), findsOneWidget);
      expect(find.textContaining('Nothing has been uploaded'), findsOneWidget);
    });

    testWidgets('a broken detector shows nothing at all', (tester) async {
      await pump(tester, FrameCheck.unavailable, null);

      // Silence, not an error. The model failing to load says nothing about
      // the photograph, and a warning here would blame the user's framing.
      expect(find.byType(Text), findsNothing);
    });
  });
}
