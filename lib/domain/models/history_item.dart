/// One past scan.
///
/// The flat string fields below are the original shape and are kept because
/// rows written by earlier versions still have only those. New rows also carry
/// [report]: the serialised [ProductReport] with its badges intact, which is
/// the only way a Verified barcode reading survives a round trip to disk.
/// Reading is handled by `report_from_history.dart`, which prefers [report]
/// and falls back to reconstructing from the strings.
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.productName,
    required this.companyName,
    required this.imagePath,
    required this.originalImagePath,
    required this.resultText,
    this.productionOrigin,
    this.hqCountry,
    this.taxCountry,
    this.report,
    required this.createdAt,
  });

  final String id;
  final String productName;
  final String companyName;
  final String imagePath;
  final String originalImagePath;
  final String resultText;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;

  /// The serialised [ProductReport]. Null on rows written before it existed.
  final Map<String, dynamic>? report;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'companyName': companyName,
        'imagePath': imagePath,
        'originalImagePath': originalImagePath,
        'resultText': resultText,
        'productionOrigin': productionOrigin,
        'hqCountry': hqCountry,
        'taxCountry': taxCountry,
        'report': report,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Not identified',
      companyName: json['companyName'] as String? ?? 'Unknown company',
      imagePath: json['imagePath'] as String? ?? '',
      originalImagePath: json['originalImagePath'] as String? ??
          json['imagePath'] as String? ??
          '',
      resultText: json['resultText'] as String? ?? '',
      productionOrigin: json['productionOrigin'] as String?,
      hqCountry: json['hqCountry'] as String?,
      taxCountry: json['taxCountry'] as String?,
      // Hive hands back Map<dynamic, dynamic>, not Map<String, dynamic>.
      report: json['report'] is Map
          ? Map<String, dynamic>.from(json['report'] as Map)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
