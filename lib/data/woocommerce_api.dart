// lib/data/woocommerce_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// WooCommerce Store API (عمومی - بدون کلید)
/// - Products:   GET /wp-json/wc/store/v1/products
/// - Categories: GET /wp-json/wc/store/v1/products/categories
class WooApi {
  final String _base = AppConfig.baseUrl;

  Uri _store(String path, [Map<String, String>? qp]) {
    return Uri.parse('$_base/wp-json/wc/store/v1/$path')
        .replace(queryParameters: qp);
  }

  /// گرفتن محصولات از Store API
  /// پارامترهای مجاز: page, per_page, order (asc/desc), orderby (date/title/price/rating/popularity)
  /// search, category (ID)
  Future<List<Map<String, dynamic>>> products({
    int page = 1,
    int per = 12,
    String? search,
    int? category,
    String order = 'desc',
    String orderBy = 'date',
  }) async {
    // نرمال‌سازی orderby برای Store API
    const valid = {'date', 'title', 'price', 'rating', 'popularity'};
    if (!valid.contains(orderBy.toLowerCase())) orderBy = 'date';

    final r = await http.get(_store('products', {
      'page': '$page',
      'per_page': '$per',
      'order': order,
      'orderby': orderBy,
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null) 'category': '$category',
    }));

    if (r.statusCode != 200) {
      throw Exception('Store products ${r.statusCode}: ${r.body}');
    }
    return (json.decode(r.body) as List).cast<Map<String, dynamic>>();
  }

  /// گرفتن دسته‌بندی‌ها از Store API
  /// خروجی شامل فیلدهای: id, name, parent, count, image{src} ...
  Future<List<Map<String, dynamic>>> categories({
    bool hideEmpty = true,
    int parent = 0, // 0=فقط سطح اول، -1=همه سطوح
  }) async {
    final r = await http.get(_store('products/categories'));
    if (r.statusCode != 200) {
      throw Exception('Store categories ${r.statusCode}: ${r.body}');
    }
    final list = (json.decode(r.body) as List).cast<Map<String, dynamic>>();

    // فیلترها
    final filtered = parent == 0
        ? list.where((m) => (m['parent'] ?? 0) == 0).toList()
        : (parent == -1
            ? list
            : list.where((m) => (m['parent'] ?? 0) == parent).toList());

    return hideEmpty
        ? filtered.where((m) => (m['count'] ?? 0) > 0).toList()
        : filtered;
  }
}
