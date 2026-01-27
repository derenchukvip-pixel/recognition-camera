import 'package:flutter/material.dart';

class ProductInfoScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductInfoScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final name = product['product_name'] ?? 'Not found';
    final brands = product['brands'] ?? '';
    final imageUrl = product['image_front_url'] as String?;
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Center(
                child: Image.network(imageUrl, height: 180),
              ),
            const SizedBox(height: 16),
            Text('Brands: $brands'),
            const SizedBox(height: 16),
            if (nutriments != null) ...[
              Text('Nutrition per 100g:', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (nutriments['energy-kcal_100g'] != null)
                Text('Calories: ${nutriments['energy-kcal_100g']} kcal'),
              if (nutriments['fat_100g'] != null)
                Text('Fat: ${nutriments['fat_100g']} g'),
              if (nutriments['carbohydrates_100g'] != null)
                Text('Carbohydrates: ${nutriments['carbohydrates_100g']} g'),
              if (nutriments['proteins_100g'] != null)
                Text('Proteins: ${nutriments['proteins_100g']} g'),
            ],
          ],
        ),
      ),
    );
  }
}
