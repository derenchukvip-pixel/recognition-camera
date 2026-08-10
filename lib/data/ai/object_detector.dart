import 'dart:io';

import '../../domain/models/detection.dart';

/// Finds objects in a photograph.
///
/// An interface for the same reason `RecognitionApi` is one: the view model
/// that drives the frame check has to be testable without a 6 MB model, a
/// native delegate and a real JPEG. The production implementation is
/// `OnDeviceAIService`.
abstract class ObjectDetector {
  /// Most confident first, at most one entry per label.
  ///
  /// Returns an empty list when the frame holds nothing recognisable, which is
  /// an answer rather than a failure — a photo of a shelf edge legitimately
  /// contains no object. Throws only when the detector itself could not run.
  Future<List<Detection>> detect(File image);
}
