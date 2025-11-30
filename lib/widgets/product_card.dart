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
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // تصویر محصول با نسبت 1:1
            AspectRatio(
              aspectRatio: 1,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, prog) {
                        if (prog == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.image_outlined, size: 48),
                      ),
                    ),
            ),
            // محتوای کارت
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم محصول کامل - حداکثر ۴ خط
                  Text(
                    name,
                    textAlign: TextAlign.start,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // قیمت محصول
                  priceWidget(),
                  const SizedBox(height: 10),
                  // کنترل تعداد (کم و زیاد کردن)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // دکمه کاهش
                            InkWell(
                              onTap: _decrementQuantity,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(50),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: _quantity > 1 ? _navyBlue : Colors.grey,
                                ),
                              ),
                            ),
                            // نمایش تعداد
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _navyBlue,
                                ),
                              ),
                            ),
                            // دکمه افزایش
                            InkWell(
                              onTap: _incrementQuantity,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(50),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: _navyBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // دکمه افزودن به سبد با رنگ سورمه‌ای
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
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
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
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
