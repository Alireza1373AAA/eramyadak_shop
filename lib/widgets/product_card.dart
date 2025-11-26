// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
import '../utils/price.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback? onTap;
  final Future<void> Function()? onCartUpdated;

  const ProductCard({
    super.key,
    required this.p,
    this.onTap,
    this.onCartUpdated,
  });

  int? _readUnitToman(Map<String, dynamic> item) {
    final possible = [
      item['unit_price'],
      item['price'],
      item['prices']?['price'],
      item['price_per_unit'],
      item['single_price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  int? _readCartonToman(Map<String, dynamic> item) {
    final possible = [
      item['carton_price'],
      item['price_per_carton'],
      item['carton']?['price'],
      item['pack_price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (p['name'] ??
                p['title'] ??
                (p['product'] is Map ? p['product']['name'] : null) ??
                '')
            .toString();

    String? imageUrl;
    final images = p['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] is String) imageUrl = first['src'];
      if (first is String) imageUrl = first;
    } else if (p['image'] is String) {
      imageUrl = p['image'];
    }

    final unitToman = _readUnitToman(p);
    final cartonToman = _readCartonToman(p);

    Widget priceWidget() {
      final children = <Widget>[];
      if (unitToman != null) {
        children.add(
          Text(
            'تکی: ${Price.formatToman(unitToman)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }
      if (cartonToman != null) {
        children.add(
          Text(
            'کارتن: ${Price.formatToman(cartonToman)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }
      if (unitToman == null && cartonToman == null) {
        children.add(
          const Text('قیمت نامشخص', style: TextStyle(color: Colors.grey)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: imageUrl == null
                    ? Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 40),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  priceWidget(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (onCartUpdated != null) await onCartUpdated!();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              12,
                              12,
                              12,
                            ),
                          ),
                          child: const Text('افزودن به سبد'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
