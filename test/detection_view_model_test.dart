import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:recognition_camera/data/recognition/recognition_api.dart';
import 'package:recognition_camera/domain/models/recognition_result.dart';
import 'package:recognition_camera/presentation/detection/detection_view_model.dart';

class FakeRecognitionApi implements RecognitionApi {
  @override
  Future<RecognitionResult> analyzeImage(File imageFile) async {
    return const RecognitionResult(message: 'ok', rawResponse: 'ok');
  }
}

void main() {
  test('analyzeImage updates status and result', () async {
    final viewModel = DetectionViewModel(recognitionApi: FakeRecognitionApi());
    viewModel.setImage(File('dummy.jpg'));

    await viewModel.analyzeImage();

    expect(viewModel.status, DetectionStatus.success);
    expect(viewModel.resultText, 'ok');
    expect(viewModel.errorMessage, isNull);
  });
}
