/// A scan the user chose to keep.
///
/// Same two-layer shape as [HistoryItem]: flat strings for rows written by
/// earlier versions, plus [report] carrying the serialised [ProductReport]
/// with its badges. See `report_from_history.dart` for how the two are read.
class SavedProduct {
  const SavedProduct({
    required this.id,
    required this.productName,
    required this.companyName,
    required this.imagePath,
    required this.originalImagePath,
    this.productionOrigin,
    this.hqCountry,
    this.taxCountry,
    this.resultText,
    this.report,
    required this.createdAt,
  });

  final String id;
  final String productName;
  final String companyName;
  final String imagePath;
  final String originalImagePath;
  final String? productionOrigin;
  final String? hqCountry;
  final String? taxCountry;
  final String? resultText;

  /// The serialised [ProductReport]. Null on rows written before it existed.
  final Map<String, dynamic>? report;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'companyName': companyName,
        'imagePath': imagePath,
        'originalImagePath': originalImagePath,
        'productionOrigin': productionOrigin,
        'hqCountry': hqCountry,
        'taxCountry': taxCountry,
        'resultText': resultText,
        'report': report,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedProduct.fromJson(Map<String, dynamic> json) {
    return SavedProduct(
      id: json['id'] as String,
      productName: json['productName'] as String? ?? 'Not identified',
      companyName: json['companyName'] as String? ?? 'Unknown company',
      imagePath: json['imagePath'] as String? ?? '',
      originalImagePath: json['originalImagePath'] as String? ??
          json['imagePath'] as String? ??
          '',
      productionOrigin: json['productionOrigin'] as String?,
      hqCountry: json['hqCountry'] as String?,
      taxCountry: json['taxCountry'] as String?,
      resultText: json['resultText'] as String?,
      // Hive hands back Map<dynamic, dynamic>, not Map<String, dynamic>.
      report: json['report'] is Map
          ? Map<String, dynamic>.from(json['report'] as Map)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
