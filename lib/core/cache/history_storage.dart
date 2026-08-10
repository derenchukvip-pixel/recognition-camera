import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/history_item.dart';
import '../../domain/models/product_report.dart';

class HistoryStorage {
  HistoryStorage({Directory? baseDir, Box? box})
      : _baseDir = baseDir,
        _box = box ?? Hive.box('history_items');

  static const int _maxItems = 100;
  static const String _itemsKey = 'items';

  final Directory? _baseDir;
  final Box _box;

  Future<List<HistoryItem>> fetchAll() async {
    final raw = _box.get(_itemsKey, defaultValue: <dynamic>[]) as List<dynamic>;
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(HistoryItem.fromJson)
        .toList();
  }

  /// [imageFile] is nullable because a barcode scan has no photograph. The
  /// row is still worth keeping — it holds a Verified registry reading, which
  /// is the strongest claim the app can make — and the result screen renders
  /// the digits where the photo would go.
  Future<HistoryItem> addItem({
    required ProductReport report,
    required String resultText,
    File? imageFile,
    String? productionOrigin,
    String? hqCountry,
    String? taxCountry,
  }) async {
    final items = await fetchAll();
    final imagePath = imageFile == null ? '' : await _persistImage(imageFile);
    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      // The flat fields are still written so a row stays readable to the
      // legacy path, but the report is what the screen actually renders.
      productName: report.productName.hasValue
          ? report.productName.displayValue
          : 'Not identified',
      companyName: report.brand.hasValue
          ? report.brand.displayValue
          : 'Unknown company',
      imagePath: imagePath,
      originalImagePath: imageFile?.path ?? '',
      resultText: resultText,
      productionOrigin: productionOrigin,
      hqCountry: hqCountry,
      taxCountry: taxCountry,
      report: report.toJson(),
      createdAt: DateTime.now(),
    );
    final updated = [item, ...items];
    final trimmed = await _trimToLimit(updated);
    await _saveAll(trimmed);
    return item;
  }

  Future<void> remove(String id) async {
    final items = await fetchAll();
    final removed = items.where((item) => item.id == id).toList();
    final updated = items.where((item) => item.id != id).toList();
    await _saveAll(updated);
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

  Future<void> _saveAll(List<HistoryItem> items) async {
    final encoded = items.map((e) => e.toJson()).toList();
    await _box.put(_itemsKey, encoded);
  }

  Future<String> _persistImage(File imageFile) async {
    final baseDir = _baseDir ?? await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/history_images');
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

  Future<List<HistoryItem>> _trimToLimit(List<HistoryItem> items) async {
    if (items.length <= _maxItems) return items;
    final trimmed = items.sublist(0, _maxItems);
    final removed = items.sublist(_maxItems);
    for (final item in removed) {
      await _deleteImage(item.imagePath);
    }
    return trimmed;
  }
}
