// lib/pages/products_page.dart
import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';
import '../utils/price.dart';
import 'product_detail.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _api = WooApi();
  final _items = <Map<String, dynamic>>[];
  final _controller = ScrollController();

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    if (_loading || (!_hasMore && !first)) return;

    setState(() {
      _loading = true;
      if (first) {
        _error = null;
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });

    try {
      final batch = await _api.products(
        page: _page,
        per: 12,
        order: 'desc',
        orderBy: 'date',
        category: widget.categoryId,
      );

      if (!mounted) return;

      setState(() {
        _items.addAll(batch);
        _page++;
        _hasMore = batch.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 300) {
      _load();
    }
  }

  String _formatPriceFromProduct(Map<String, dynamic> p) {
    final sale = p['sale_price'] ?? p['prices']?['sale_price'] ?? p['price'];
    final regular =
        p['regular_price'] ?? p['prices']?['regular_price'] ?? p['price'];
    final use = (sale != null && sale.toString().isNotEmpty) ? sale : regular;
    return Price.formatToman(use);
  }

  Map<String, Object?> _productStockInfo(Map<String, dynamic> p) {
    bool? inStock;
    int? qty;

    if (p['stock_status'] != null) {
      final s = p['stock_status'].toString().toLowerCase();
      if (s.contains('instock')) inStock = true;
      if (s.contains('outofstock')) inStock = false;
    }
    if (p['in_stock'] is bool) inStock = p['in_stock'] as bool;
    if (p['is_in_stock'] is bool) inStock = p['is_in_stock'] as bool;
    if (p['stock_quantity'] is num) qty = (p['stock_quantity'] as num).toInt();
    inStock ??= true;

    String text;
    Color color;
    if (!inStock) {
      text = 'ناموجود';
      color = Colors.redAccent;
    } else if (qty != null) {
      if (qty <= 5) {
        text = 'فقط $qty عدد';
        color = Colors.orange;
      } else {
        text = 'موجود';
        color = Colors.green;
      }
    } else {
      text = 'موجود';
      color = Colors.green;
    }

    return {'inStock': inStock, 'qty': qty, 'text': text, 'color': color};
  }

  @override
  Widget build(BuildContext context) {
    // تعداد ستون‌ها بر اساس عرض صفحه (حداقل 2، حداکثر 4)
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth ~/ 180).clamp(
      2,
      4,
    ); // هر کارت 180px عرض
    final childAspectRatio = 0.68; // ارتفاع کارت تقریبی

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.categoryName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _load(first: true),
            ),
          ],
        ),
        body: _buildBody(crossAxisCount, childAspectRatio),
      ),
    );
  }

  Widget _buildBody(int crossAxisCount, double childAspectRatio) {
    if (_error != null && _items.isEmpty) {
      return _ErrorView(message: _error!, onRetry: () => _load(first: true));
    }

    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('محصولی یافت نشد.'));
    }

    return RefreshIndicator(
      onRefresh: () => _load(first: true),
      child: CustomScrollView(
        controller: _controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = _items[i];
                final rawName = (p['name'] ?? '').toString();
                final name = rawName.replaceAll(RegExp(r'<[^>]*>'), '').trim();

                String? img;
                final images = p['images'];
                if (images is List && images.isNotEmpty) {
                  final first = images.first;
                  if (first is Map && first['src'] is String) {
                    img = first['src'] as String;
                  } else if (first is String) {
                    img = first;
                  }
                }

                final priceText = _formatPriceFromProduct(p);
                final stock = _productStockInfo(p);
                final stockText = stock['text'] as String;
                final stockColor = stock['color'] as Color;

                return Card(
                  elevation: 1.5,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetail(product: p),
                        ),
                      ).then((_) => _load(first: true));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: img != null
                              ? Hero(
                                  tag: 'product_image_${p['id'] ?? i}',
                                  child: Image.network(
                                    img,
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
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.image_outlined, size: 48),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      priceText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      color: stockColor.withOpacity(0.12),
                                      border: Border.all(
                                        color: stockColor.withOpacity(0.38),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      stockText,
                                      style: TextStyle(
                                        color: stockColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
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
              }, childCount: _items.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : (_hasMore
                          ? TextButton(
                              onPressed: () => _load(),
                              child: const Text('بارگذاری بیشتر'),
                            )
                          : const Text('همهٔ موارد نمایش داده شد')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            const Text('خطا در دریافت محصولات'),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
          ],
        ),
      ),
    );
  }
}
