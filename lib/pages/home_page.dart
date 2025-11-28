// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';
import '../data/store_api.dart' as store;
import '../widgets/product_card.dart';
import 'product_detail.dart';
import 'cart_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = WooApi();
  final _scroll = ScrollController();
  final store.StoreApi _storeApi = store.StoreApi();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cats = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';

  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCats();
    _scroll.addListener(_maybeMore);
    _warmupStore();
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeMore() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _load();
    }
  }

  Future<void> _warmupStore() async {
    try {
      await _storeApi.ensureSession();
      await _refreshCartBadge();
    } catch (_) {}
  }

  Future<void> _refreshCartBadge() async {
    try {
      final raw = await _storeApi.getCart();
      final count = _cartItemCountFromResponse(raw);
      if (mounted) setState(() => _cartCount = count);
    } catch (e) {
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  int _cartItemCountFromResponse(dynamic cart) {
    if (cart is Map) {
      if (cart['item_count'] is int) return cart['item_count'];
      if (cart['items_count'] is int) return cart['items_count'];
      if (cart['count'] is int) return cart['count'];

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

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;

    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      if (mounted) setState(() {});
    }
    if (!_hasMore) return;

    setState(() => _loading = true);
    try {
      final data = await api.products(
        page: _page,
        per: 12,
        search: _search.isEmpty ? null : _search,
      );

      if (data.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
        _items.addAll(data);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCats() async {
    try {
      final cats = await api.categories();
      if (!mounted) return;
      setState(() => _cats = cats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('Eram Yadak'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
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
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'جستجوی محصول',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _search = v.trim();
                _load(refresh: true);
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load(refresh: true);
          await _refreshCartBadge();
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const _ResponsiveBanner(
              assetPath: 'assets/baner/پوستر-موبایل (1).jpg',
              fit: BoxFit.cover,
              borderRadius: 16,
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            ),

            if (_cats.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (c, i) {
                    final cat = _cats[i];
                    final catId = cat['id'];
                    final catName = (cat['name'] ?? '').toString();
                    return ActionChip(
                      label: Text(catName),
                      onPressed: () async {
                        _search = '';
                        _items.clear();
                        _page = 1;
                        _hasMore = true;
                        setState(() {});

                        final v = await api.products(
                          page: 1,
                          per: 12,
                          category: catId,
                        );
                        if (!mounted) return;

                        setState(() {
                          _items = List<Map<String, dynamic>>.from(v);
                          _page = 2;
                          _hasMore = v.isNotEmpty;
                        });
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _cats.length,
                ),
              ),
              const SizedBox(height: 12),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'جدیدترین محصولات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _load(refresh: true),
                    child: const Text('مشاهده همه'),
                  ),
                ],
              ),
            ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .48,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _items.length + (_loading ? 2 : 0),
              itemBuilder: (ctx, i) {
                if (i >= _items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final p = _items[i];
                return ProductCard(
                  p: p,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetail(product: p),
                    ),
                  ),
                  onCartUpdated: _refreshCartBadge,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------

/// Responsive banner widget
class _ResponsiveBanner extends StatefulWidget {
  const _ResponsiveBanner({
    required this.assetPath,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(0),
    this.fit = BoxFit.cover,
    this.placeholderColor = const Color(0xFFF2F2F2),
  });

  final String assetPath;
  final double borderRadius;
  final EdgeInsets padding;
  final BoxFit fit;
  final Color placeholderColor;

  @override
  State<_ResponsiveBanner> createState() => _ResponsiveBannerState();
}

class _ResponsiveBannerState extends State<_ResponsiveBanner> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    final img = AssetImage(widget.assetPath);
    final stream = img.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted && w > 0 && h > 0) {
          setState(() => _aspect = w / h);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _aspect == null
            ? AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: widget.placeholderColor),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxWidth / _aspect!;
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Image.asset(
                      widget.assetPath,
                      fit: widget.fit,
                      errorBuilder: (_, __, ___) => Container(
                        color: widget.placeholderColor,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
