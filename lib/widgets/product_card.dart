// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
import '../utils/price.dart';

/// رنگ سورمه‌ای برای دکمه افزودن به سبد خرید
const Color _navyBlue = Color(0xFF1A237E);

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
  int _quantity = 1;

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

  Future<void> _addToCart() async {
    setState(() => _loading = true);
    try {
      final productId = widget.p['id'];
      if (productId == null) throw Exception('Product ID is null');
      
      await _api.ensureSession();
      final id = (productId is int) ? productId : int.parse(productId.toString());
      await _api.addToCart(productId: id, quantity: _quantity);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_quantity عدد محصول به سبد خرید اضافه شد'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Reset quantity after successful add
      setState(() => _quantity = 1);
      
      if (widget.onCartUpdated != null) {
        await widget.onCartUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _incrementQuantity() {
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.p['name'] ??
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
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
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم محصول کامل - حداکثر ۴ خط
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    priceWidget(),
                    const SizedBox(height: 8),
                    // کنترل تعداد (کم و زیاد کردن)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // دکمه کاهش
                              Tooltip(
                                message: 'کاهش تعداد',
                                child: IconButton(
                                  onPressed: _decrementQuantity,
                                  icon: const Icon(Icons.remove, size: 18,
                                    semanticLabel: 'کاهش تعداد',
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              // نمایش تعداد
                              Container(
                                constraints: const BoxConstraints(minWidth: 32),
                                alignment: Alignment.center,
                                child: Semantics(
                                  label: 'تعداد: $_quantity',
                                  child: Text(
                                    '$_quantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              // دکمه افزایش
                              Tooltip(
                                message: 'افزایش تعداد',
                                child: IconButton(
                                  onPressed: _incrementQuantity,
                                  icon: const Icon(Icons.add, size: 18,
                                    semanticLabel: 'افزایش تعداد',
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // دکمه افزودن به سبد با رنگ سورمه‌ای
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _addToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navyBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'افزودن به سبد',
                                    style: TextStyle(fontSize: 13),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
