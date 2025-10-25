// lib/pages/products_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';

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
      _load(); // بارگذاری صفحه‌های بعدی (infinite scroll)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.categoryName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _load(first: true),
            )
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = _items[i];
                  final name = (p['name'] ?? '').toString();
                  final price = (p['prices']?['price'] ?? p['price_html'] ?? '')
                      .toString();
                  String? img;
                  final images = p['images'];
                  if (images is List && images.isNotEmpty) {
                    final first = images.first;
                    if (first is Map && first['src'] is String) {
                      img = first['src'] as String;
                    }
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () {
                        // TODO: صفحهٔ جزئیات محصول
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: img != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: Image.network(
                                      img,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined,
                                        size: 48, color: Colors.grey),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                if (price.isNotEmpty)
                                  Text(
                                    price,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _items.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .64,
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
