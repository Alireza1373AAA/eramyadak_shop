// lib/data/store_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StoreConfig {
  /// دامنه‌ی فروشگاهت (بدون / انتهایی)
  static const String baseUrl = 'https://eramyadak.com';

  /// تایم‌اوت برای درخواست‌ها
  static const Duration requestTimeout = Duration(seconds: 25);
}

/// خطای ساده برای گزارش وضعیت HTTP
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}

/// API لایت WooCommerce Store API برای کار با «سبد خرید»
class StoreApi {
  // -------- Singleton (برای اشتراک کوکی و nonce در کل اپ) --------
  StoreApi._internal();
  static final StoreApi _instance = StoreApi._internal();
  factory StoreApi() => _instance;

  final http.Client _client = http.Client();

  /// کوکی و نونس بین تمام نقاط اپ مشترک می‌ماند
  static String _cookie = '';
  static String _storeApiNonce = '';

  // ------------------------ Helpers ------------------------

  Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('${StoreConfig.baseUrl}$path').replace(queryParameters: qp);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    // بعضی سرورها برای استخراج نونس به این دو هدر متکی‌اند
    'Origin': StoreConfig.baseUrl,
    'Referer': StoreConfig.baseUrl,
    'Accept-Language': 'fa-IR,fa;q=0.9,en-US;q=0.8,en;q=0.7',
    'User-Agent': 'EramYadakFlutter/1.0 (Android; Flutter)',
    if (_cookie.isNotEmpty) 'Cookie': _cookie,
    if (_storeApiNonce.isNotEmpty) 'X-WC-Store-API-Nonce': _storeApiNonce,
  };

  /// کوکی‌ها و نونس را از Response استخراج می‌کند
  void _captureAuthFromResponse(http.BaseResponse r) {
    // — Cookie —
    final setCookie = r.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // پاسخ‌های چندکوکی با کاما جدا می‌شوند (اما ممکن است در attributes هم کاما باشد)
      final parts = setCookie.split(RegExp(r',(?=\s*\w+=)'));
      final keep = <String>[];
      for (final p in parts) {
        final kv = p.split(';').first.trim();
        if (kv.startsWith('wp_woocommerce_session_') ||
            kv.startsWith('woocommerce_items_in_cart') ||
            kv.startsWith('woocommerce_cart_hash')) {
          keep.add(kv);
        }
      }
      if (keep.isNotEmpty) {
        final existing = _cookie
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        for (final k in keep) {
          existing.removeWhere((e) => e.split('=').first == k.split('=').first);
          existing.add(k);
        }
        _cookie = existing.join('; ');
      }
    }

    // — Nonce —
    String? nonce;
    r.headers.forEach((k, v) {
      final key = k.toLowerCase();
      if (key == 'x-wc-store-api-nonce' || key == 'x-wp-nonce') {
        nonce = v;
      }
    });
    if (nonce != null && nonce!.isNotEmpty) {
      _storeApiNonce = nonce!;
    }
  }

  /// درخواست با تایم‌اوت + گرفتن کوکی/نانس
  Future<http.Response> _get(Uri url) async {
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(StoreConfig.requestTimeout);
    _captureAuthFromResponse(resp);
    return resp;
  }

  Future<http.Response> _post(Uri url, Object? body) async {
    final resp = await _client
        .post(url, headers: _headers, body: json.encode(body))
        .timeout(StoreConfig.requestTimeout);
    _captureAuthFromResponse(resp);
    return resp;
  }

  // ------------------------ Public APIs ------------------------

  /// ابتدا سبد را GET می‌کنیم تا Session و Nonce ساخته شود
  Future<void> ensureSession() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200) {
      throw HttpException('Cart init ${r.statusCode}: ${r.body}');
    }
  }

  /// دریافت وضعیت فعلی سبد
  Future<Map<String, dynamic>> getCart() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200) {
      throw HttpException('Cart ${r.statusCode}: ${r.body}');
    }
    return json.decode(r.body) as Map<String, dynamic>;
  }

  /// افزودن آیتم به سبد.
  ///
  /// - برای محصول ساده: فقط [productId] و [quantity] کافی است.
  /// - برای محصول متغیر:
  ///   - اگر [variationId] را می‌دانی، همان را بده.
  ///   - یا می‌توانی به‌جای آن [attributes] بدهی، مثلاً:
  ///     `{'pa_size':'xl', 'pa_color':'black'}`
  Future<void> addToCart({
    required int productId,
    int quantity = 1,
    int? variationId,
    Map<String, String>? attributes,
  }) async {
    Future<http.Response> _doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/add-item'), {
          'id': productId,
          'quantity': quantity,
          if (variationId != null) 'variation_id': variationId,
          if (attributes != null && attributes.isNotEmpty)
            'variation': attributes.entries
                .map((e) => {'attribute': e.key, 'value': e.value})
                .toList(),
        });

    var r = await _doPost();

    // اگر نونس/سشن مشکل داشت، یک‌بار session را تازه کن و دوباره بفرست
    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }

    if (r.statusCode != 200 && r.statusCode != 201) {
      throw HttpException('Add item ${r.statusCode}: ${r.body}');
    }
  }

  /// تغییر تعداد یک آیتم در سبد
  Future<void> updateItemQty({
    required String itemKey,
    required int quantity,
  }) async {
    Future<http.Response> _doPost() => _post(
      _u('/wp-json/wc/store/v1/cart/update-item'),
      {'key': itemKey, 'quantity': quantity},
    );

    var r = await _doPost();

    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }

    if (r.statusCode != 200) {
      throw HttpException('Update qty ${r.statusCode}: ${r.body}');
    }
  }

  /// حذف یک آیتم از سبد
  Future<void> removeItem({required String itemKey}) async {
    Future<http.Response> _doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/remove-item'), {'key': itemKey});

    var r = await _doPost();

    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }

    if (r.statusCode != 200) {
      throw HttpException('Remove ${r.statusCode}: ${r.body}');
    }
  }

  /// خالی‌کردن سبد
  Future<void> clearCart() async {
    Future<http.Response> _doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/clear'), {});

    var r = await _doPost();

    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }

    if (r.statusCode != 200) {
      throw HttpException('Clear cart ${r.statusCode}: ${r.body}');
    }
  }

  // ------------------------ Expose for WebView ------------------------

  /// رشتهٔ کوکی فعلی (برای ارسال به WebView تا همان سبد دیده شود)
  String get cookieString => _cookie;

  /// اگر لازم شد جای دیگر استفاده کنی
  String get nonce => _storeApiNonce;
}
