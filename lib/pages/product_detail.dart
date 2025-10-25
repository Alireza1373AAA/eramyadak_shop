// lib/pages/product_detail.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store; // alias
import '../utils/price.dart';
import 'cart_page.dart';

class ProductDetail extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetail({super.key, required this.product});

  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  final store.StoreApi _api = store.StoreApi();
  int _quantity = 1;
  bool _loading = false;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _warmup();
  }

  Future<void> _warmup() async {
    await _api.ensureSession();
    await _refreshCartBadge();
  }

  Future<void> _refreshCartBadge() async {
    try {
      final raw = await _api.getCart();
      final count = _cartItemCountFromResponse(raw);
      if (mounted) setState(() => _cartCount = count);
    } catch (_) {
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  int _cartItemCountFromResponse(dynamic cart) {
    if (cart is Map) {
      if (cart['item_count'] is int) return cart['item_count'] as int;
      if (cart['count'] is int) return cart['count'] as int;
      final lists = [
        cart['items'],
        cart['line_items'],
        cart['cart_items'],
        cart['cart_contents'],
      ].whereType<List>();
      if (lists.isNotEmpty) {
        int sum = 0;
        for (final it in lists.first) {
          if (it is Map && it['quantity'] is num) {
            sum += (it['quantity'] as num).round();
          } else {
            sum += 1;
          }
        }
        return sum;
      }
    }
    return 0;
  }

  Future<void> _addToCart() async {
    final int? productId = widget.product['id'] as int?;
    if (productId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('شناسه محصول نامعتبر است.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.ensureSession();
      await _api.addToCart(productId: productId, quantity: _quantity);
      if (!mounted) return;
      await _refreshCartBadge();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_quantity عدد "${widget.product['name']}" به سبد اضافه شد.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      _openCartBottomSheet(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در افزودن به سبد: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .8,
        child: const CartPage(), // از صفحه سبد کامل استفاده کن
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = (p['name'] ?? '').toString();
    final priceRaw = p['price'] ?? p['regular_price'] ?? p['sale_price'];
    final priceText = Price.formatToman(priceRaw);

    final desc = (p['short_description'] ?? p['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '');

    final images = (p['images'] as List?) ?? const [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            IconButton(
              tooltip: 'جستجو',
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'سبد خرید',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  ).then((_) => _refreshCartBadge()),
                  icon: const Icon(Icons.shopping_cart_outlined),
                ),
                if (_cartCount > 0)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (images.isNotEmpty)
              AspectRatio(
                aspectRatio: 1.2,
                child: PageView(
                  children: [
                    for (final img in images)
                      if (img is Map && img['src'] is String)
                        Image.network(
                          img['src'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            Text(
              priceText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (desc.isNotEmpty)
              Text(desc, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _loading ? null : _addToCart,
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart),
              label: Text(_loading ? 'در حال افزودن...' : 'افزودن به سبد'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _openCartBottomSheet(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('مشاهده سبد در این صفحه'),
            ),
          ],
        ),
      ),
    );
  }
}
