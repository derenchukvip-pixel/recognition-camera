import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/product_report.dart';
import '../../domain/models/saved_product.dart';

class SavedProductsStorage {
  SavedProductsStorage({Directory? baseDir, Box? box})
      : _baseDir = baseDir,
        _box = box ?? Hive.box('saved_products');

  static const String _itemsKey = 'items';
  static const int _maxItems = 100;
  final Directory? _baseDir;
  final Box _box;

  Future<List<SavedProduct>> fetchAll() async {
    final raw = _box.get(_itemsKey, defaultValue: <dynamic>[]) as List<dynamic>;
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(SavedProduct.fromJson)
        .toList();
  }

  /// [imageFile] is null for a barcode scan, which has no photograph. Those
  /// are deduplicated by barcode instead of by image path — the same product
  /// scanned twice is one saved entry either way.
  Future<SavedProduct> addProduct({
    required ProductReport report,
    File? imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
    String? resultText,
  }) async {
    final matched = imageFile != null
        ? await findByImagePath(imageFile.path)
        : await findByBarcode(report.barcode);
    if (matched != null) {
      return matched;
    }

    final imagePath = imageFile == null ? '' : await _persistImage(imageFile);
    final product = SavedProduct(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productName: report.productName.hasValue
          ? report.productName.displayValue
          : 'Not identified',
      companyName: report.brand.hasValue
          ? report.brand.displayValue
          : 'Unknown company',
      imagePath: imagePath,
      originalImagePath: imageFile?.path ?? '',
      productionOrigin: productionOrigin,
      hqCountry: hqCountry,
      taxCountry: taxCountry,
      resultText: resultText,
      report: report.toJson(),
      createdAt: DateTime.now(),
    );
    final items = await fetchAll();
    final updated = [product, ...items];
    final trimmed = await _trimToLimit(updated);
    await _saveAll(trimmed);
    return product;
  }

  Future<bool> existsForImage(String imagePath) async {
    final items = await fetchAll();
    return items.any(
      (item) =>
          item.originalImagePath == imagePath || item.imagePath == imagePath,
    );
  }

  /// Barcode scans have no image to key on, so they are matched by the digits
  /// instead. Rows saved before the report was stored have no barcode and are
  /// skipped rather than treated as a match for everything.
  Future<SavedProduct?> findByBarcode(String? barcode) async {
    if (barcode == null || barcode.isEmpty) return null;
    for (final item in await fetchAll()) {
      if (item.report?['barcode'] == barcode) return item;
    }
    return null;
  }

  Future<SavedProduct?> findByImagePath(String imagePath) async {
    final items = await fetchAll();
    try {
      return items.firstWhere(
        (item) =>
            item.originalImagePath == imagePath || item.imagePath == imagePath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    final items = await fetchAll();
    final removed = items.where((item) => item.id == id).toList();
    items.removeWhere((item) => item.id == id);
    await _saveAll(items);
    for (final item in removed) {
      await _deleteImage(item.imagePath);
    }
  }

  Future<void> clearAll() async {
    final items = await fetchAll();
    await _saveAll([]);
    for (final item in items) {
      await _deleteImage(item.imagePath);
    }
  }

  Future<void> _saveAll(List<SavedProduct> items) async {
    final encoded = items.map((e) => e.toJson()).toList();
    await _box.put(_itemsKey, encoded);
  }

  Future<List<SavedProduct>> _trimToLimit(List<SavedProduct> items) async {
    if (items.length <= _maxItems) return items;
    final trimmed = items.sublist(0, _maxItems);
    final removed = items.sublist(_maxItems);
    for (final item in removed) {
      await _deleteImage(item.imagePath);
    }
    return trimmed;
  }

  Future<String> _persistImage(File imageFile) async {
    final baseDir = _baseDir ?? await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/saved_images');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetPath =
        '${targetDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await imageFile.copy(targetPath);
    return targetPath;
  }

  Future<void> _deleteImage(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
