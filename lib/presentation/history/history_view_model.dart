import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/history_storage.dart';
import '../../domain/models/history_item.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({HistoryStorage? storage})
      : _storage = storage ?? HistoryStorage() {
    _load();
  }

  final HistoryStorage _storage;

  List<HistoryItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<HistoryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _storage.fetchAll();
      _error = null;
    } catch (error) {
      _error = 'Unable to load history.';
      if (kDebugMode) {
        debugPrint('History load error: $error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFromResult({
    required String productName,
    required String companyName,
    required String resultText,
    required File imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
  }) async {
    try {
      final item = await _storage.addItem(
        productName: productName,
        companyName: companyName,
        resultText: resultText,
        imageFile: imageFile,
        productionOrigin: productionOrigin,
        hqCountry: hqCountry,
        taxCountry: taxCountry,
      );
      _items = [item, ..._items.where((entry) => entry.id != item.id)];
      if (_items.length > 100) {
        _items = _items.sublist(0, 100);
      }
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('History add error: $error');
      }
    }
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
