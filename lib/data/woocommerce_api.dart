// lib/data/woocommerce_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:http/http.dart' as http;
import 'package:eramyadak_shop/config.dart';

class WooApiException implements Exception {
  final String message;
  final int? statusCode;
  WooApiException(this.message, {this.statusCode});
  @override
  String toString() => 'WooApiException($statusCode): $message';
}

class WooApi {
  final String _base = AppConfig.baseUrl;

  // -----------------------
  // helper for v3 urls
  // -----------------------
  Uri _wooV3(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$_base/wp-json/wc/v3/$path');
    return params == null
        ? uri
        : uri.replace(
            queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
          );
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('${AppConfig.wcKey}:${AppConfig.wcSecret}'))}';

  // -----------------------
  // CookieJar + Dio
  // -----------------------
  final CookieJar _cookieJar = CookieJar();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json, */*',
        'Content-Type': 'application/json',
      },
    ),
  )..interceptors.add(CookieManager(_cookieJar)); // <-- use single CookieJar

  WooApi() {
    if (kIsWeb) {
      final adapter = BrowserHttpClientAdapter();
      adapter.withCredentials = true;
      _dio.httpClientAdapter = adapter;
    }
    // Optional: uncomment to enable request/response logs in debug
    // if (kDebugMode) {
    //   _dio.interceptors.add(LogInterceptor(request: true, responseBody: true, requestBody: true));
    // }
  }

  // -----------------------
  // Store API Nonce (cached)
  // -----------------------
  String? _cachedNonce;
  DateTime? _nonceAt;

  /// دریافت نانس (و در همین درخواست کوکی session نیز ست می‌شود)
  Future<String> _getStoreNonce() async {
    if (_cachedNonce != null &&
        _nonceAt != null &&
        DateTime.now().difference(_nonceAt!) < const Duration(minutes: 8)) {
      return _cachedNonce!;
    }

    final res = await _dio.get(
      '/wp-json/eram/v1/store-nonce',
      options: Options(extra: {'withCredentials': true}),
    );

    if (res.statusCode == 200 && res.data is Map && res.data['nonce'] != null) {
      _cachedNonce = res.data['nonce'] as String;
      _nonceAt = DateTime.now();
      debugPrint('WooApi: fetched nonce=$_cachedNonce');
      return _cachedNonce!;
    }

    throw WooApiException('دریافت نانس ناموفق بود', statusCode: res.statusCode);
  }

  /// پاک کردن کش نانس (در صورت لزوم)
  void clearStoreNonceCache() {
    _cachedNonce = null;
    _nonceAt = null;
  }

  /// اطمینان از وجود session/nonce قبل از عملیات‌هایی مثل افزودن به سبد
  Future<void> ensureSession() async {
    // _getStoreNonce هم کوکی‌ها را از سرور می‌گیرد (withCredentials = true)
    try {
      await _getStoreNonce();
    } catch (e) {
      // برای اطمینان می‌توان یک درخواست ساده هم به root زد تا cookie ست شود
      try {
        await _dio.get('/', options: Options(extra: {'withCredentials': true}));
        // سپس دوباره تلاش برای نانس
        await _getStoreNonce();
      } catch (_) {
        rethrow;
      }
    }
  }

  // -----------------------
  // Helpers: stock detection (copied/adapted)
  // -----------------------
  bool? _mapIndicatesInStock(Map<String, dynamic>? p) {
    if (p == null) return null;

    for (final key in ['in_stock', 'is_in_stock', 'available', 'stocked']) {
      if (!p.containsKey(key)) continue;
      final v = p[key];
      if (v is bool) return v;
      if (v is num) return v > 0;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'true' ||
            s == '1' ||
            s.contains('موجود') ||
            s.contains('in stock'))
          return true;
        if (s == 'false' ||
            s == '0' ||
            s.contains('ناموجود') ||
            s.contains('out of stock'))
          return false;
      }
    }

    if (p.containsKey('stock_status')) {
      final ss = (p['stock_status']?.toString().toLowerCase() ?? '');
      if (ss.contains('instock') ||
          ss.contains('onbackorder') ||
          ss.contains('available'))
        return true;
      if (ss.contains('outofstock') || ss.contains('unavailable')) return false;
    }

    if (p.containsKey('stock_quantity')) {
      final q = int.tryParse(p['stock_quantity']?.toString() ?? '') ?? 0;
      return q > 0;
    }

    if (p.containsKey('availability')) {
      final av = (p['availability']?.toString().toLowerCase() ?? '');
      if (av.contains('موجود') ||
          av.contains('in stock') ||
          av.contains('available'))
        return true;
      if (av.contains('ناموجود') ||
          av.contains('out of stock') ||
          av.contains('unavailable'))
        return false;
    }

    return null;
  }

  Future<bool> _determineInStockFromV3(int id) async {
    try {
      final r = await http.get(
        _wooV3('products/$id'),
        headers: {'Authorization': _authHeader},
      );
      if (r.statusCode != 200) return false;
      final detail = jsonDecode(r.body) as Map<String, dynamic>;
      final type = (detail['type'] ?? '').toString();
      final stockStatus = detail['stock_status']?.toString().toLowerCase();
      if (stockStatus != null) {
        if (stockStatus == 'instock' || stockStatus == 'onbackorder')
          return true;
        if (stockStatus == 'outofstock') return false;
      }
      if (detail.containsKey('stock_quantity')) {
        final q = int.tryParse(detail['stock_quantity']?.toString() ?? '') ?? 0;
        if (q > 0) return true;
      }
      if (type == 'variable') {
        try {
          final varsRes = await http.get(
            _wooV3('products/$id/variations', {'per_page': '100'}),
            headers: {'Authorization': _authHeader},
          );
          if (varsRes.statusCode == 200) {
            final vars = jsonDecode(varsRes.body);
            if (vars is List) {
              for (final v in vars) {
                if (v is Map<String, dynamic>) {
                  final mv = _mapIndicatesInStock(v);
                  if (mv == true) return true;
                  final vs = v['stock_status']?.toString().toLowerCase();
                  if (vs == 'instock' || vs == 'onbackorder') return true;
                  final vq =
                      int.tryParse(v['stock_quantity']?.toString() ?? '') ?? 0;
                  if (vq > 0) return true;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('WooApi: error fetching variations for $id: $e');
        }
      }
      return false;
    } catch (e) {
      debugPrint('WooApi: determineInStockFromV3 error for id=$id: $e');
      return false;
    }
  }

  // -----------------------
  // Categories (with pagination)
  // -----------------------
  Future<List<Map<String, dynamic>>> categories({
    int? parent,
    bool hideEmpty = false,
    int perPage = 100,
  }) async {
    final List<Map<String, dynamic>> all = [];
    int page = 1;

    while (true) {
      http.Response res;
      try {
        res = await http.get(
          _wooV3('products/categories', {
            'per_page': perPage,
            'page': page,
            if (parent != null) 'parent': parent,
            'hide_empty': hideEmpty,
          }),
          headers: {'Authorization': _authHeader},
        );
      } catch (e) {
        throw WooApiException('خطا در اتصال به سرور: $e');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final part = decoded.cast<Map<String, dynamic>>();
          if (part.isEmpty) break;
          all.addAll(part);
          if (part.length < perPage) break;
          page++;
        } else {
          break;
        }
      } else if (res.statusCode == 400 &&
          res.body.contains('rest_post_invalid_page_number')) {
        break;
      } else {
        throw WooApiException(
          'خطا در دریافت دسته‌ها: ${res.body}',
          statusCode: res.statusCode,
        );
      }
    }

    return all;
  }

  // -----------------------
  // Products (Store API v1) + fallback v3 for missing stock info
  // -----------------------
  Future<List<Map<String, dynamic>>> products({
    int page = 1,
    int per = 10,
    int? category,
    String order = 'desc',
    String orderBy = 'date',
    String? search,
  }) async {
    final Map<String, dynamic> query = {
      'page': page,
      'per_page': per,
      'orderby': orderBy,
      'order': order,
      'context': 'view',
      if (category != null) 'category': category,
      if (search != null) 'search': search.trim(),
    };

    final res = await _dio.get(
      '/wp-json/wc/store/v1/products',
      queryParameters: query,
    );

    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();

      // quick stock detection, fall back to v3 if needed
      final suspicious = <int>[];
      for (final p in list) {
        try {
          final quick = _mapIndicatesInStock(p);
          if (quick != null) {
            p['stock_status'] = quick ? 'instock' : 'outofstock';
          } else {
            final idDyn = p['id'];
            final id = (idDyn is int)
                ? idDyn
                : int.tryParse(idDyn?.toString() ?? '');
            if (id != null) suspicious.add(id);
          }
        } catch (e) {
          p['stock_status'] = p['stock_status'] ?? 'instock';
        }
      }

      for (final id in suspicious) {
        try {
          final r2 = await http.get(
            _wooV3('products/$id'),
            headers: {'Authorization': _authHeader},
          );
          if (r2.statusCode == 200) {
            final detail = jsonDecode(r2.body) as Map<String, dynamic>;
            final idx = list.indexWhere((p) {
              final idDyn = p['id'];
              final pid = (idDyn is int)
                  ? idDyn
                  : int.tryParse(idDyn?.toString() ?? '');
              return pid == id;
            });
            if (idx >= 0) {
              final target = list[idx];
              final stockStatus =
                  (detail['stock_status']?.toString().toLowerCase() ?? '');
              if (stockStatus == 'instock' || stockStatus == 'onbackorder')
                target['stock_status'] = 'instock';
              else if (stockStatus == 'outofstock')
                target['stock_status'] = 'outofstock';
              else {
                final q =
                    int.tryParse(detail['stock_quantity']?.toString() ?? '') ??
                    0;
                target['stock_status'] = (q > 0) ? 'instock' : 'outofstock';
              }
              if (detail.containsKey('stock_quantity'))
                target['stock_quantity'] = detail['stock_quantity'];
              if (detail['type'] == 'variable' &&
                  detail.containsKey('variations'))
                target['variations'] = detail['variations'];
            }
          }
        } catch (e) {
          debugPrint('WooApi: v3 fallback error for id=$id: $e');
        }
      }

      return list;
    }

    throw WooApiException(
      'خطا در دریافت محصولات (Store API)',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> product(int id) async {
    try {
      final res = await _dio.get('/wp-json/wc/store/v1/products/$id');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final p = Map<String, dynamic>.from(res.data as Map);
        final quick = _mapIndicatesInStock(p);
        if (quick != null)
          p['stock_status'] = quick ? 'instock' : 'outofstock';
        else
          p['stock_status'] = await _determineInStockFromV3(id)
              ? 'instock'
              : 'outofstock';

        if (!p.containsKey('stock_quantity')) {
          final r2 = await http.get(
            _wooV3('products/$id'),
            headers: {'Authorization': _authHeader},
          );
          if (r2.statusCode == 200) {
            final detail = jsonDecode(r2.body) as Map<String, dynamic>;
            if (detail.containsKey('stock_quantity'))
              p['stock_quantity'] = detail['stock_quantity'];
            if (detail.containsKey('variations'))
              p['variations'] = detail['variations'];
          }
        }
        return p;
      }
    } catch (e) {
      debugPrint('WooApi: store v1 product fetch failed for id=$id: $e');
    }

    final r = await http.get(
      _wooV3('products/$id'),
      headers: {'Authorization': _authHeader},
    );
    if (r.statusCode == 200) {
      final detail = jsonDecode(r.body) as Map<String, dynamic>;
      final p = Map<String, dynamic>.from(detail);
      final stockStatus =
          (detail['stock_status']?.toString().toLowerCase() ?? '');
      if (stockStatus == 'instock' || stockStatus == 'onbackorder')
        p['stock_status'] = 'instock';
      else if (stockStatus == 'outofstock')
        p['stock_status'] = 'outofstock';
      else if (detail.containsKey('stock_quantity')) {
        final q = int.tryParse(detail['stock_quantity']?.toString() ?? '') ?? 0;
        p['stock_status'] = q > 0 ? 'instock' : 'outofstock';
      } else if ((detail['type'] ?? '') == 'variable') {
        p['stock_status'] = await _determineInStockFromV3(id)
            ? 'instock'
            : 'outofstock';
      } else {
        p['stock_status'] = 'outofstock';
      }
      return p;
    }

    throw WooApiException(
      'خطا در دریافت جزئیات محصول',
      statusCode: r.statusCode,
    );
  }

  // -----------------------
  // CART: named params to match ProductDetail usage
  // -----------------------
  Future<void> addToCart({required int productId, int quantity = 1}) async {
    final nonce = await _getStoreNonce();
    final res = await _dio.post(
      '/wp-json/wc/store/v1/cart/add-item',
      data: {'id': productId, 'quantity': quantity},
      options: Options(
        headers: {'X-WC-Store-API-Nonce': nonce},
        extra: {'withCredentials': true},
      ),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      // invalidate nonce so next call refetches
      clearStoreNonceCache();
      throw WooApiException('خطا در افزودن به سبد', statusCode: res.statusCode);
    }
  }

  Future<void> updateCartItem({
    required String key,
    required int quantity,
  }) async {
    final nonce = await _getStoreNonce();
    final res = await _dio.post(
      '/wp-json/wc/store/v1/cart/update-item',
      data: {'key': key, 'quantity': quantity},
      options: Options(
        headers: {'X-WC-Store-API-Nonce': nonce},
        extra: {'withCredentials': true},
      ),
    );

    if (res.statusCode != 200) {
      clearStoreNonceCache();
      throw WooApiException(
        'خطا در بروزرسانی آیتم سبد',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> removeCartItem({required String key}) async {
    final nonce = await _getStoreNonce();
    final res = await _dio.post(
      '/wp-json/wc/store/v1/cart/remove-item',
      data: {'key': key},
      options: Options(
        headers: {'X-WC-Store-API-Nonce': nonce},
        extra: {'withCredentials': true},
      ),
    );

    if (res.statusCode != 200) {
      clearStoreNonceCache();
      throw WooApiException('خطا در حذف آیتم سبد', statusCode: res.statusCode);
    }
  }

  Future<void> clearCart() async {
    final nonce = await _getStoreNonce();
    final res = await _dio.post(
      '/wp-json/wc/store/v1/cart/clear',
      data: {},
      options: Options(
        headers: {'X-WC-Store-API-Nonce': nonce},
        extra: {'withCredentials': true},
      ),
    );

    if (res.statusCode != 200) {
      clearStoreNonceCache();
      throw WooApiException('خطا در خالی کردن سبد', statusCode: res.statusCode);
    }
  }

  Future<Map<String, dynamic>> getCart() async {
    final res = await _dio.get(
      '/wp-json/wc/store/v1/cart',
      options: Options(extra: {'withCredentials': true}),
    );
    if (res.statusCode == 200 && res.data is Map<String, dynamic>)
      return res.data as Map<String, dynamic>;
    throw WooApiException('خطا در دریافت سبد', statusCode: res.statusCode);
  }

  // -----------------------
  // Customers & orders (kept simple)
  // -----------------------
  Future<Map<String, dynamic>?> createCustomer({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final email = "${phone.replaceAll('+', '')}@eramyadak.com";
    final body = {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': email,
      'password': 'auto_${DateTime.now().millisecondsSinceEpoch}',
      'billing': {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email,
      },
      'shipping': {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    };

    final res = await http.post(
      _wooV3('customers'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 201 || res.statusCode == 200)
      return jsonDecode(res.body);
    if (res.statusCode == 400) {
      final lower = res.body.toLowerCase();
      if (lower.contains('existing_user_login') ||
          lower.contains('registration-error-email-exists') ||
          lower.contains('existing_user_email') ||
          lower.contains('existing_customer'))
        return null;
    }
    throw WooApiException(
      'خطا در ایجاد کاربر: ${res.body}',
      statusCode: res.statusCode,
    );
  }

  Future<bool> customerExists({required String phone}) async {
    final cleaned = phone.replaceAll('+', '').trim();
    final email = '$cleaned@eramyadak.com';

    Future<http.Response> _get(Uri u) =>
        http.get(u, headers: {'Authorization': _authHeader});

    try {
      final uriByEmail = _wooV3('customers', {'per_page': 1, 'email': email});
      final res = await _get(uriByEmail);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) return true;
        return false;
      }

      final uriSearch = _wooV3('customers', {'per_page': 1, 'search': email});
      final res2 = await _get(uriSearch);
      if (res2.statusCode == 200) {
        final decoded2 = jsonDecode(res2.body);
        if (decoded2 is List && decoded2.isNotEmpty) return true;
        return false;
      }

      throw WooApiException(
        'خطا در بررسی مشتری: ${res.body}',
        statusCode: res.statusCode,
      );
    } catch (e) {
      if (e is WooApiException) rethrow;
      throw WooApiException('خطا در بررسی وجود مشتری: $e');
    }
  }

  // createOrderCheque left as-is: adapt headers/secret as your backend expects
  Future<Map<String, dynamic>> createOrderCheque({
    required Map<String, dynamic> billing,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? meta,
  }) async {
    final url = Uri.parse('$_base/wp-json/eram/v1/create-order-cheque');
    final payload = {
      'billing': billing,
      'items': items,
      if (shipping != null) 'shipping': shipping,
      if (meta != null) 'meta': meta,
    };

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-ERAM-KEY': 'YOUR_SHARED_SECRET_HERE',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw WooApiException(
      data['error']?.toString() ?? 'خطا در ایجاد سفارش با چک',
      statusCode: res.statusCode,
    );
  }
}
