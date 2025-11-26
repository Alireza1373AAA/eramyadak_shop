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
  final WooApi api = WooApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cats = [];

  // حالت نمایش: true = درختی، false = لیست تخت
  bool _hierarchical = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  int _toInt(dynamic v, {int fallback = -1}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return fallback;
      final onlyDigits = RegExp(r'\d+').stringMatch(s);
      if (onlyDigits != null) return int.tryParse(onlyDigits) ?? fallback;
      return int.tryParse(s) ?? fallback;
    }
    return fallback;
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await api.categories(hideEmpty: false); // مهم: تمام دسته‌ها
      if (!mounted) return;

      final normalized = <Map<String, dynamic>>[];
      for (final e in cats) {
        if (e is Map<String, dynamic>)
          normalized.add(e);
        else if (e is Map)
          normalized.add(Map<String, dynamic>.from(e));
      }

      setState(() => _cats = normalized);

      // debug: بررسی تعداد دسته‌ها
      debugPrint('cats=${_cats.length}');
      debugPrint(
        _cats
            .take(10)
            .map(
              (c) => {'id': c['id'], 'parent': c['parent'], 'name': c['name']},
            )
            .toList()
            .toString(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<int, List<Map<String, dynamic>>> _buildChildrenMap(
    List<Map<String, dynamic>> cats,
  ) {
    final Map<int, List<Map<String, dynamic>>> childrenById = {};
    for (final c in cats) {
      final id = _toInt(c['id']);
      final parent = _toInt(c['parent'] ?? 0);
      childrenById.putIfAbsent(parent, () => []).add(c);
      childrenById.putIfAbsent(id, () => []);
    }
    return childrenById;
  }

  List<Map<String, dynamic>> _findRoots(List<Map<String, dynamic>> cats) {
    final allIds = cats.map((c) => _toInt(c['id'])).toSet();
    final roots = cats.where((c) {
      final parent = _toInt(c['parent'] ?? 0);
      return parent == 0 || !allIds.contains(parent);
    }).toList();
    return roots.isEmpty ? cats : roots;
  }

  Widget _leadingFor(Map<String, dynamic> cat) {
    String? imageUrl;
    final img = cat['image'];
    if (img is Map && img['src'] is String && (img['src'] as String).isNotEmpty)
      imageUrl = img['src'] as String;
    else if (cat['images'] is List && (cat['images'] as List).isNotEmpty) {
      final first = (cat['images'] as List).first;
      if (first is String && first.isNotEmpty) imageUrl = first;
      if (first is Map && first['src'] is String)
        imageUrl = first['src'] as String;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.category),
        ),
      );
    }
    return const SizedBox(width: 44, height: 44, child: Icon(Icons.category));
  }

  Widget _buildTreeView() {
    final childrenById = _buildChildrenMap(_cats);
    final roots = _findRoots(_cats);

    Widget node(Map<String, dynamic> cat) {
      final id = _toInt(cat['id']);
      final name = (cat['name'] ?? '').toString();
      final slug = (cat['slug'] ?? '').toString();
      final children = childrenById[id] ?? [];

      if (children.isEmpty) {
        return ListTile(
          leading: _leadingFor(cat),
          title: Text(name),
          onTap: () => _openCategory(context, id: id, name: name, slug: slug),
        );
      }

      return ExpansionTile(
        key: ValueKey('cat_$id'),
        leading: _leadingFor(cat),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        initiallyExpanded: true,
        children: children.map(node).toList(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: roots.length,
      itemBuilder: (ctx, i) {
        final c = roots[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: node(c),
        );
      },
    );
  }

  Widget _buildFlatIndentedView() {
    final childrenById = _buildChildrenMap(_cats);
    final roots = _findRoots(_cats);
    final rows = <Widget>[];

    void walk(Map<String, dynamic> cat, int depth) {
      final id = _toInt(cat['id']);
      final name = (cat['name'] ?? '').toString();
      final slug = (cat['slug'] ?? '').toString();

      rows.add(
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 12.0 + depth * 16.0,
            right: 12.0,
          ),
          leading: _leadingFor(cat),
          title: Text(name),
          onTap: () => _openCategory(context, id: id, name: name, slug: slug),
        ),
      );

      final children = childrenById[id] ?? [];
      for (final c in children) walk(c, depth + 1);
    }

    for (final r in roots) walk(r, 0);

    return ListView(padding: const EdgeInsets.all(12), children: rows);
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
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'بروزرسانی',
            ),
            IconButton(
              icon: Icon(_hierarchical ? Icons.list : Icons.account_tree),
              tooltip: _hierarchical ? 'نمایش تخت' : 'نمایش درختی',
              onPressed: () => setState(() => _hierarchical = !_hierarchical),
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
              ElevatedButton(
                onPressed: _loadAll,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }
    if (_cats.isEmpty)
      return const Center(child: Text('هیچ دسته‌ای یافت نشد.'));

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _hierarchical ? _buildTreeView() : _buildFlatIndentedView(),
    );
  }

  Future<void> _openCategory(
    BuildContext context, {
    required int? id,
    required String name,
    required String slug,
  }) async {
    if (id != null && id >= 0) {
      try {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductsPage(categoryId: id, categoryName: name),
          ),
        );
        return;
      } catch (_) {}
    }

    if (slug.isNotEmpty) {
      final uri = Uri.parse('https://eramyadak.com/product-category/$slug/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان باز کردن دسته وجود ندارد.')),
      );
    }
  }
}
