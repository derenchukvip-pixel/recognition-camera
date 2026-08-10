import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/saved_products_storage.dart';
import '../../domain/models/product_report.dart';
import '../../domain/models/saved_product.dart';

class SavedProductsViewModel extends ChangeNotifier {
  SavedProductsViewModel({SavedProductsStorage? storage})
      : _storage = storage ?? SavedProductsStorage() {
    _load();
  }

  final SavedProductsStorage _storage;

  List<SavedProduct> _items = [];
  bool _isLoading = false;
  String? _error;

  List<SavedProduct> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isSaved(String imagePath) => _findByImagePath(imagePath) != null;

  /// A barcode scan has no photo, so it is identified by its digits. Without
  /// this the bookmark on a barcode result could never show as filled, and
  /// tapping it twice would save the same product twice.
  bool isBarcodeSaved(String? barcode) => _findByBarcode(barcode) != null;

  SavedProduct? _findByImagePath(String imagePath) {
    if (imagePath.isEmpty) return null;
    for (final item in _items) {
      if (item.originalImagePath == imagePath || item.imagePath == imagePath) {
        return item;
      }
    }
    return null;
  }

  SavedProduct? _findByBarcode(String? barcode) {
    if (barcode == null || barcode.isEmpty) return null;
    for (final item in _items) {
      if (item.report?['barcode'] == barcode) return item;
    }
    return null;
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _storage.fetchAll();
      _error = null;
    } catch (error) {
      _error = 'Unable to load saved items.';
      if (kDebugMode) {
        debugPrint('SavedProducts load error: $error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFromResult({
    required ProductReport report,
    File? imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
    String? resultText,
  }) async {
    try {
      final alreadySaved = imageFile != null
          ? isSaved(imageFile.path)
          : isBarcodeSaved(report.barcode);
      if (alreadySaved) return;
      final product = await _storage.addProduct(
        report: report,
        imageFile: imageFile,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
        taxCountry: taxCountry,
        resultText: resultText,
      );
      _items = [product, ..._items.where((item) => item.id != product.id)];
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SavedProducts add error: $error');
      }
    }
  }

  Future<void> toggleFromResult({
    required ProductReport report,
    File? imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
    String? resultText,
  }) async {
    final existing = imageFile != null
        ? _findByImagePath(imageFile.path)
        : _findByBarcode(report.barcode);
    if (existing != null) {
      await remove(existing.id);
      return;
    }
    await addFromResult(
      report: report,
      imageFile: imageFile,
      productionOrigin: productionOrigin,
      hqCountry: hqCountry,
      taxCountry: taxCountry,
      resultText: resultText,
    );
  }

  Future<void> remove(String id) async {
    await _storage.remove(id);
    _items = _items.where((item) => item.id != id).toList();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    _items = [];
    notifyListeners();
  }
}
