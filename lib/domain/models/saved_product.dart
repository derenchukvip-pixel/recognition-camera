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
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedProduct.fromJson(Map<String, dynamic> json) {
    return SavedProduct(
      id: json['id'] as String,
      productName: json['productName'] as String? ?? 'Unknown product',
      companyName: json['companyName'] as String? ?? 'Unknown company',
      imagePath: json['imagePath'] as String? ?? '',
      originalImagePath: json['originalImagePath'] as String? ??
          json['imagePath'] as String? ??
          '',
      productionOrigin: json['productionOrigin'] as String?,
      hqCountry: json['hqCountry'] as String?,
      taxCountry: json['taxCountry'] as String?,
      resultText: json['resultText'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
