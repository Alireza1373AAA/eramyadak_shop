// lib/pages/product_detail.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
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

  late final PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _warmup();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _warmup() async {
    try {
      await _api.ensureSession();
      await _refreshCartBadge();
    } catch (_) {}
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
      if (cart['items_count'] is int) return cart['items_count'] as int;
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

  // ---------------- Price helpers similar to cart_page ----------------

  /// تلاش برای خواندن قیمت واحد به تومان یا بازگشت null
  int? _readUnitTomanFromProduct(Map<String, dynamic> p) {
    final possible = [
      p['unit_price'],
      p['price'],
      p['prices']?['price'],
      p['price_per_unit'],
      p['single_price'],
      p['regular_price'],
      p['sale_price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  /// تلاش برای خواندن قیمت کارتن (اگر موجود باشد)
  int? _readCartonTomanFromProduct(Map<String, dynamic> p) {
    final possible = [
      p['carton_price'],
      p['price_per_carton'],
      p['carton']?['price'],
      p['pack_price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  /// نمایش قیمت اصلی/تخفیف‌خورده به صورت رشته فرمت‌شده
  /// الویت: sale_price (اگر کمتر از regular باشد) -> regular -> unitToman -> carton
  String _displayPrice(Map<String, dynamic> p) {
    final sale = Price.toTomanNullable(p['sale_price'] ?? p['price']);
    final regular = Price.toTomanNullable(p['regular_price'] ?? p['price']);
    final unit = _readUnitTomanFromProduct(p);
    final carton = _readCartonTomanFromProduct(p);

    // اگر sale و regular هر دو موجود و sale < regular -> نمایش sale + خط خوردن regular
    if (regular != null && sale != null && sale < regular) {
      final saleTxt = Price.formatToman(sale);
      final regTxt = Price.formatToman(regular);
      return '$saleTxt  ▸  $regTxt'; // UI code will show reg as line-through
    }

    if (sale != null && sale > 0) return Price.formatToman(sale);
    if (regular != null && regular > 0) return Price.formatToman(regular);
    if (unit != null) return Price.formatToman(unit);
    if (carton != null) return Price.formatToman(carton);

    return '—';
  }

  /// جداکننده برای استخراج مقادیر دقیق sale/regular برای UI
  int? _priceValue(Map<String, dynamic> p, String which) {
    final v = which == 'sale'
        ? (p['sale_price'] ?? p['price'])
        : (p['regular_price'] ?? p['price']);
    return Price.toTomanNullable(v);
  }

  // ---------------- Add to cart ----------------

  Future<void> _addToCart() async {
    final int? productId = widget.product['id'] is int
        ? widget.product['id']
        : int.tryParse('${widget.product['id']}');

    if (productId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شناسه محصول نامعتبر است.')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.ensureSession();
      await _api.addToCart(productId: productId, quantity: _quantity);
      if (!mounted) return;
      await _refreshCartBadge();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_quantity عدد "${_safeName()}" به سبد اضافه شد.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در افزودن به سبد: $e'),
          backgroundColor: Colors.red.shade700,
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
        height: MediaQuery.of(ctx).size.height * .85,
        child: const CartPage(),
      ),
    );
  }

  String _safeName() {
    final rawName = (widget.product['name'] ?? '').toString();
    final name = rawName.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return name.isEmpty ? 'بدون نام' : name;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = _safeName();

    // تصاویر
    final images = (p['images'] as List?) ?? [];
    final imageUrls = <String>[];
    for (final img in images) {
      if (img is Map && img['src'] is String)
        imageUrls.add(img['src'] as String);
      else if (img is String)
        imageUrls.add(img);
    }

    // قیمت‌ها برای نمایش
    final saleVal = _priceValue(p, 'sale');
    final regVal = _priceValue(p, 'regular');
    final displayPrice = _displayPrice(p);

    final hasSale = (regVal != null && saleVal != null && saleVal < regVal);
    final discountPercent = (regVal != null && saleVal != null && regVal > 0)
        ? (((regVal - saleVal) / regVal) * 100).round()
        : 0;

    final desc = (p['short_description'] ?? p['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    final sku = (p['sku'] ?? '').toString();
    final inStock = p['stock_status'] == 'instock' || p['is_in_stock'] == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: const Text(
            'جزئیات محصول',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
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
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            // title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 44, height: 4, color: Colors.orange),
                  ],
                ),
              ),
            ),

            // image carousel
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final aspect = width > 600 ? 1.6 : 1.2;
                    return Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: imageUrls.isNotEmpty
                            ? PageView.builder(
                                controller: _pageController,
                                itemCount: imageUrls.length,
                                onPageChanged: (i) =>
                                    setState(() => _currentImage = i),
                                itemBuilder: (_, i) => Image.network(
                                  imageUrls[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                  loadingBuilder: (_, child, prog) =>
                                      prog == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // price card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // نمایش قیمت: اگر تخفیف هست sale در جلو و regular خط خورده نمایش داده شود
                              if (hasSale)
                                Row(
                                  children: [
                                    Text(
                                      Price.formatToman(saleVal ?? 0),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${discountPercent}% ',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  displayPrice,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                              if (hasSale)
                                Text(
                                  Price.formatToman(regVal ?? 0),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),

                              if (sku.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('کد محصول: $sku'),
                                ),
                            ],
                          ),
                        ),

                        // quantity controls
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$_quantity'),
                            IconButton(
                              onPressed: () => setState(() => _quantity++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (desc.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'توضیحات محصول',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(desc),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),

        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_shopping_cart_outlined),
                    label: Text(
                      _loading
                          ? 'در حال افزودن...'
                          : 'افزودن $_quantity به سبد',
                    ),
                    onPressed: _loading ? null : _addToCart,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: () => _openCartBottomSheet(context),
                    child: const Text('مشاهد سبد خرید'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
