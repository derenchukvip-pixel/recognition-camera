import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:recognition_camera/core/cache/saved_products_storage.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/report_from_history.dart';
import 'package:recognition_camera/domain/models/saved_product.dart';
import 'package:recognition_camera/domain/provenance.dart';

ProductReport _photoReport({String name = 'Sample Product'}) => ProductReport(
      productName: ProvenanceClaim(
        value: name,
        provenance: Provenance.estimated,
        source: 'Image recognition',
      ),
      brand: const ProvenanceClaim(
        value: 'Sample Company',
        provenance: Provenance.estimated,
        source: 'Image recognition',
      ),
      registeredIn: const ProvenanceClaim.unknown(),
      manufacturedIn: const ProvenanceClaim.unknown(),
      headquarters: const ProvenanceClaim.unknown(),
    );

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
      report: _photoReport(),
      imageFile: sourceImage,
    );

    final items = await storage.fetchAll();
    expect(items.length, 1);
    expect(items.first.id, saved.id);

    await storage.remove(saved.id);
    final empty = await storage.fetchAll();
    expect(empty, isEmpty);
  });

  test('a saved scan keeps its badges across the round trip', () async {
    // The reason the report is stored at all. A barcode scan's Verified
    // registry reading used to be unrecoverable from disk — the old record
    // held five loose strings and the adapter could only ever answer
    // "estimated at best", so saving one silently downgraded it.
    final storage = SavedProductsStorage(baseDir: tempDir);

    await storage.addProduct(
      report: ProductReport(
        barcode: '5702016616545',
        productName: const ProvenanceClaim(
          value: 'Recycling Truck 42107',
          provenance: Provenance.verified,
          source: 'Open Food Facts',
        ),
        brand: const ProvenanceClaim.unknown(),
        registeredIn: ProductReport.fromBarcode('5702016616545'),
        manufacturedIn: const ProvenanceClaim.unknown(),
        headquarters: const ProvenanceClaim.unknown(),
      ),
    );

    final restored = (await storage.fetchAll()).single.toReport();

    expect(restored.productName.provenance, Provenance.verified);
    expect(restored.registeredIn.provenance, Provenance.verified);
    expect(restored.registeredIn.value, 'Denmark');
    expect(restored.registeredIn.source, 'GS1 prefix 570');
    expect(restored.hasVerifiedClaim, isTrue);
    // No photograph was involved, and the restored report must not claim one.
    expect(restored.source, ScanSource.barcode);
  });

  test('the same barcode is not saved twice', () async {
    final storage = SavedProductsStorage(baseDir: tempDir);
    final report = ProductReport(
      barcode: '5702016616545',
      productName: const ProvenanceClaim.unknown(),
      brand: const ProvenanceClaim.unknown(),
      registeredIn: ProductReport.fromBarcode('5702016616545'),
      manufacturedIn: const ProvenanceClaim.unknown(),
      headquarters: const ProvenanceClaim.unknown(),
    );

    final first = await storage.addProduct(report: report);
    final second = await storage.addProduct(report: report);

    expect(second.id, first.id);
    expect((await storage.fetchAll()).length, 1);
  });

  test('a legacy row without a stored report still opens', () async {
    // Rows written before the report existed must keep working, downgraded
    // rather than dropped: nothing recovered from them can be verified,
    // because the justification was never recorded.
    final storage = SavedProductsStorage(baseDir: tempDir);
    final sourceImage = File('${tempDir.path}/legacy.jpg');
    await sourceImage.writeAsBytes([0, 1, 2, 3]);
    await storage.addProduct(
      report: _photoReport(name: 'Legacy Product'),
      imageFile: sourceImage,
    );

    final row = (await storage.fetchAll()).single;
    final legacy = SavedProduct(
      id: row.id,
      productName: row.productName,
      companyName: row.companyName,
      imagePath: row.imagePath,
      originalImagePath: row.originalImagePath,
      createdAt: row.createdAt,
    );

    final report = legacy.toReport();
    expect(report.productName.value, 'Legacy Product');
    expect(report.productName.provenance, Provenance.estimated);
    expect(report.hasVerifiedClaim, isFalse);
  });
}
