import 'package:dio/dio.dart';

import '../../core/cache/simple_cache.dart';
import '../../core/config/app_config.dart';
import '../../core/network/dio_client.dart';

class OpenFoodFactsApi {
  OpenFoodFactsApi({Dio? dio, SimpleCache<Map<String, dynamic>>? cache})
      : _dio = dio ?? createDio(baseUrl: AppConfig.openFoodFactsBaseUrl),
        _cache = cache ?? SimpleCache<Map<String, dynamic>>(ttl: _defaultTtl);

  final Dio _dio;
  final SimpleCache<Map<String, dynamic>> _cache;

  static const Duration _defaultTtl = Duration(days: 7);

  Future<Map<String, dynamic>?> fetchProduct(String barcode) async {
    final cached = _cache.get(barcode);
    if (cached != null) {
      return cached;
    }

    final response = await _dio.get('/api/v0/product/$barcode.json');
    final data = response.data;
    if (response.statusCode == 200 && data is Map<String, dynamic>) {
      if (data['status'] == 1 && data['product'] is Map<String, dynamic>) {
        final product = Map<String, dynamic>.from(data['product']);
        _cache.set(barcode, product);
        return product;
      }
    }
    return null;
  }
}
