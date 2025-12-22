// lib/pages/products_page.dart
import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';
import '../widgets/product_card.dart';
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

  @override
  Widget build(BuildContext context) {
    // محاسبه ریسپانسیو بر اساس عرض صفحه
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375; // iPhone SE
    final isMediumScreen = screenWidth >= 375 && screenWidth < 414;
    final isLargeScreen = screenWidth >= 600;
    
    // تعداد ستون‌ها بر اساس اندازه صفحه
    final crossAxisCount = isLargeScreen ? 3 : 2;
    
    // نسبت ابعاد کارت - کوچکتر = بلندتر
    final childAspectRatio = isSmallScreen 
        ? 0.42  // کارت بلندتر برای iPhone SE
        : (isMediumScreen ? 0.46 : 0.48);
    
    // فاصله بین کارت‌ها
    final spacing = isSmallScreen ? 8.0 : 12.0;

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
        body: _buildBody(crossAxisCount, childAspectRatio, spacing),
      ),
    );
  }

  Widget _buildBody(int crossAxisCount, double childAspectRatio, double spacing) {
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
            padding: EdgeInsets.all(spacing),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = _items[i];

                return ProductCard(
                  p: p,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetail(product: p),
                      ),
                    ).then((_) => _load(first: true));
                  },
                  onCartUpdated: () async {
                    // refresh cart after adding
                  },
                );
              }, childCount: _items.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
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
