/// One object the on-device model found in the frame.
///
/// A COCO class, not a product. The distinction is the whole reason this type
/// is separate from [ProductReport]: the detector can say "there is a bottle
/// here", and it can never say which bottle. Presenting the two in the same
/// shape would invite exactly the conflation the provenance model exists to
/// prevent.
class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String label;
  final double confidence;

  /// Top-left corner and size, in source-image pixels.
  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get area => width * height;
}

/// What to tell the user about the frame, in one line.
///
/// Returns null when nothing was found, so the caller can say something
/// different rather than printing an empty list. Labels come from the COCO set
/// in lower case ("cell phone", "potted plant"), and the first is capitalised
/// rather than title-cased: "Cell phone in frame" reads like a sentence,
/// "Cell Phone In Frame" reads like a heading.
String? framedObjectsSummary(List<Detection> detections, {int limit = 3}) {
  final labels = <String>[];
  for (final detection in detections) {
    if (!labels.contains(detection.label)) labels.add(detection.label);
    if (labels.length == limit) break;
  }
  if (labels.isEmpty) return null;

  final String listed;
  if (labels.length == 1) {
    listed = labels.first;
  } else {
    listed = '${labels.sublist(0, labels.length - 1).join(', ')}'
        ' and ${labels.last}';
  }
  return '${listed[0].toUpperCase()}${listed.substring(1)} in frame';
}
