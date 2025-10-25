// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';
import '../widgets/product_card.dart';
import 'product_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = WooApi();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cats = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadCats();
    _scroll.addListener(_maybeMore);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در دریافت محصولات: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCats() async {
    try {
      final cats = await api.categories();
      if (!mounted) return;
      setState(() => _cats = cats);
    } catch (_) {
      // می‌تونی لاگ بگیری یا پیام نمایش بدی
    }
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
            tooltip: 'بروزرسانی',
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
        onRefresh: () => _load(refresh: true),
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // --- بنر ریسپانسیو از assets (نسبت از خود تصویر خوانده می‌شود) ---
            const _ResponsiveBanner(
              assetPath: 'assets/baner/پوستر-موبایل (1).jpg',
              // اگر هیچ برشی نمی‌خوای: fit: BoxFit.contain,
              fit: BoxFit.cover,
              borderRadius: 16,
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            ),

            // --- چیپ‌های دسته‌بندی ---
            if (_cats.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (c, i) {
                    final cat = _cats[i];
                    final catId = cat['id'] as int;
                    final catName = (cat['name'] ?? '').toString();
                    return ActionChip(
                      label: Text(catName),
                      onPressed: () async {
                        _search = '';
                        _items.clear();
                        _page = 1;
                        _hasMore = true;
                        setState(() {}); // رفرش سریع UI

                        try {
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
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطا در دسته‌بندی: $e')),
                          );
                        }
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _cats.length,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // --- تیتر ---
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

            // --- گرید محصولات ---
            if (_items.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('محصولی یافت نشد'),
                  ],
                ),
              ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .62,
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ویجت بنر ریسپانسیو: نسبت تصویر را از خود فایل می‌خواند تا دقیق فیت شود.
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
  double? _aspect; // width / height

  @override
  void initState() {
    super.initState();

    final img = AssetImage(widget.assetPath);
    final stream = img.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (mounted && w > 0 && h > 0) {
            setState(() => _aspect = w / h);
          }
        },
        onError: (err, _) {
          // اختیاری: لاگ
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _aspect == null
            // تا وقتی ابعاد لود نشده، یک اسکلت با نسبت 16/9 نمایش بده
            ? AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: widget.placeholderColor),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // ارتفاع را از عرض و نسبت واقعی تصویر حساب می‌کنیم
                  final height = constraints.maxWidth / _aspect!;
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Image.asset(
                      widget.assetPath,
                      fit: widget.fit, // cover یا contain
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
