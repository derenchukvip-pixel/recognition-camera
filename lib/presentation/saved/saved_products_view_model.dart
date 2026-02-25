import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/saved_products_storage.dart';
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
  bool isSaved(String imagePath) => _items.any(
        (item) =>
            item.originalImagePath == imagePath || item.imagePath == imagePath,
      );

  SavedProduct? _findByImagePath(String imagePath) {
    try {
      return _items.firstWhere(
        (item) =>
            item.originalImagePath == imagePath || item.imagePath == imagePath,
      );
    } catch (_) {
      return null;
    }
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
    required String productName,
    required String companyName,
    required File imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
    String? resultText,
  }) async {
    try {
      if (isSaved(imageFile.path)) return;
      final product = await _storage.addProduct(
        productName: productName,
        companyName: companyName,
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
    required String productName,
    required String companyName,
    required File imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
    String? resultText,
  }) async {
    final existing = _findByImagePath(imageFile.path);
    if (existing != null) {
      await remove(existing.id);
      return;
    }
    await addFromResult(
      productName: productName,
      companyName: companyName,
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
