// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
import '../utils/price.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> p;
  final VoidCallback? onTap;
  final Future<void> Function()? onCartUpdated;

  const ProductCard({
    super.key,
    required this.p,
    this.onTap,
    this.onCartUpdated,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final store.StoreApi _api = store.StoreApi();
  bool _loading = false;

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

  bool? _stockTextIndicatesInStock(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      for (final entry in value.values) {
        final parsed = _stockTextIndicatesInStock(entry);
        if (parsed != null) return parsed;
      }
      return null;
    }
    if (value is Iterable) {
      for (final entry in value) {
        final parsed = _stockTextIndicatesInStock(entry);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final text = value.toString().toLowerCase();
    if (text.isEmpty) return null;
    if (text.contains('outofstock') ||
        text.contains('out of stock') ||
        text.contains('product_out_of_stock') ||
        text.contains('unavailable') ||
        text.contains('ناموجود') ||
        text.contains('تمام شد') ||
        text.contains('عدم موجودی')) {
      return false;
    }
    if (text.contains('instock') ||
        text.contains('in stock') ||
        text.contains('onbackorder') ||
        text.contains('available') ||
        text.contains('موجود')) {
      return true;
    }
    return null;
  }

  bool _isInStock(Map<String, dynamic> item) {
    for (final key in ['in_stock', 'is_in_stock', 'available', 'stocked']) {
      final value = item[key];
      if (value is bool) return value;
      if (value is num) return value > 0;
      final parsed = _stockTextIndicatesInStock(value);
      if (parsed != null) return parsed;
    }

    for (final key in [
      'stock_status',
      'stock_availability',
      'availability',
      'availability_html',
      'stock_html',
    ]) {
      final parsed = _stockTextIndicatesInStock(item[key]);
      if (parsed != null) return parsed;
    }

    if (item.containsKey('stock_quantity')) {
      final qty = int.tryParse(item['stock_quantity']?.toString() ?? '');
      if (qty != null) return qty > 0;
    }

    return true;
  }

  bool _isOutOfStockError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('product_out_of_stock') ||
        text.contains('out_of_stock') ||
        text.contains('outofstock') ||
        text.contains('out of stock') ||
        text.contains('ناموجود') ||
        text.contains('موجودی');
  }

  Future<void> _addToCart() async {
    if (!_isInStock(widget.p)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این محصول ناموجود است.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final productId = widget.p['id'];
      if (productId == null) throw Exception('Product ID is null');

      await _api.ensureSession();
      final id =
          (productId is int) ? productId : int.parse(productId.toString());
      await _api.addToCart(productId: id, quantity: 1);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('محصول به سبد خرید اضافه شد'),
          duration: Duration(seconds: 2),
        ),
      );

      if (widget.onCartUpdated != null) {
        await widget.onCartUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      if (_isOutOfStockError(e)) {
        widget.p['stock_status'] = 'outofstock';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('این محصول ناموجود است.')),
        );
        setState(() {});
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.p['name'] ??
            widget.p['title'] ??
            (widget.p['product'] is Map ? widget.p['product']['name'] : null) ??
            '')
        .toString();

    String? imageUrl;
    final images = widget.p['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] is String) imageUrl = first['src'];
      if (first is String) imageUrl = first;
    } else if (widget.p['image'] is String) {
      imageUrl = widget.p['image'];
    }

    final unitToman = _readUnitToman(widget.p);
    final cartonToman = _readCartonToman(widget.p);
    final inStock = _isInStock(widget.p);

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
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl == null
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 40,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                    if (!inStock)
                      Container(color: Colors.white.withOpacity(.58)),
                    if (!inStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ناموجود',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                          onPressed: (_loading || !inStock) ? null : _addToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              12,
                              12,
                              12,
                            ),
                            disabledBackgroundColor: Colors.grey.shade500,
                            disabledForegroundColor: Colors.white,
                          ),
                          child: Text(
                            inStock ? 'افزودن به سبد' : 'ناموجود',
                          ),
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
