import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:recognition_camera/core/cache/saved_products_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('saved_products');
    Hive.init(tempDir.path);
    await Hive.openBox('saved_products');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('adds and removes saved products', () async {
    final storage = SavedProductsStorage(baseDir: tempDir);

    final sourceImage = File('${tempDir.path}/source.jpg');
    await sourceImage.writeAsBytes([0, 1, 2, 3]);

    final saved = await storage.addProduct(
      productName: 'Sample Product',
      companyName: 'Sample Company',
      imageFile: sourceImage,
    );

    final items = await storage.fetchAll();
    expect(items.length, 1);
    expect(items.first.id, saved.id);

    await storage.remove(saved.id);
    final empty = await storage.fetchAll();
    expect(empty, isEmpty);
  });
}
