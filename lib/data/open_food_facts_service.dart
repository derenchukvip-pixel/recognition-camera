import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsService {
  static Future<Map<String, dynamic>?> fetchProduct(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1) {
        return data['product'] as Map<String, dynamic>;
      }
    }
    return null;
  }
}
