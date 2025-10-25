// lib/pages/categories_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/woocommerce_api.dart';
import 'products_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final api = WooApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await api.categories(
        hideEmpty: true,
        parent: 0, // فقط سطح اول
      );
      if (!mounted) return;
      setState(() => _cats = cats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دسته‌بندی‌ها'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'بروزرسانی',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              const Text('خطا در دریافت دسته‌ها'),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _load, child: const Text('تلاش مجدد')),
            ],
          ),
        ),
      );
    }

    if (_cats.isEmpty) {
      return const Center(child: Text('هیچ دسته‌ای یافت نشد.'));
    }

    // مهم: Grid باید اسکرولیبل باشد تا RefreshIndicator کار کند
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: _cats.length,
        itemBuilder: (context, i) {
          final cat = _cats[i];

          final id = cat['id'] is int ? cat['id'] as int : null;
          final name = (cat['name'] ?? '').toString();
          final slug = (cat['slug'] ?? '').toString();

          // تصویر امن
          String? imageUrl;
          final img = cat['image'];
          if (img is Map) {
            final src = img['src'];
            if (src is String && src.isNotEmpty) imageUrl = src;
          }

          return Card(
            clipBehavior: Clip.antiAlias, // برای Ripple درست
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () =>
                  _openCategory(context, id: id, name: name, slug: slug),
              child: Column(
                children: [
                  Expanded(
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const Center(
                                    child: Icon(Icons.category, size: 40)),
                          )
                        : const Center(
                            child: Icon(Icons.category,
                                size: 60, color: Colors.grey),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCategory(BuildContext context,
      {required int? id, required String name, required String slug}) async {
    // 1) تلاش برای ناوبری داخل اپ
    if (id != null) {
      try {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductsPage(
              categoryId: id,
              categoryName: name,
            ),
          ),
        );
        return;
      } catch (_) {
        // اگر ناوبری به هر دلیلی خطا داد، میریم سراغ باز کردن لینک سایت
      }
    }

    // 2) fallback: باز کردن لینک سایت همان دسته
    if (slug.isNotEmpty) {
      final uri = Uri.parse('https://eramyadak.com/product-category/$slug/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // اگر هیچ‌کدام ممکن نبود، به کاربر بگو
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان باز کردن دسته وجود ندارد.')),
      );
    }
  }
}
