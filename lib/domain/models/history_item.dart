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
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Unknown product',
      companyName: json['companyName'] as String? ?? 'Unknown company',
      imagePath: json['imagePath'] as String? ?? '',
      originalImagePath: json['originalImagePath'] as String? ??
          json['imagePath'] as String? ??
          '',
      resultText: json['resultText'] as String? ?? '',
      productionOrigin: json['productionOrigin'] as String?,
      hqCountry: json['hqCountry'] as String?,
      taxCountry: json['taxCountry'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
