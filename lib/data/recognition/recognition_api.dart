import 'dart:io';
import '../../domain/models/recognition_result.dart';

abstract class RecognitionApi {
  Future<RecognitionResult> analyzeImage(File imageFile);
}
