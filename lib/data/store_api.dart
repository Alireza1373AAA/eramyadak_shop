import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:eramyadak_shop/config.dart';

/// تنظیمات پایه برای Store API
class StoreConfig {
  static const String baseUrl = 'https://eramyadak.com';
  static const Duration requestTimeout = Duration(seconds: 25);
}

/// خطای ساده برای گزارش وضعیت HTTP
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}

/// API کامل WooCommerce + Eram Store برای سبد خرید و ثبت سفارش چک
class StoreApi {
  // Singleton
  StoreApi._internal();
  static final StoreApi _instance = StoreApi._internal();
  factory StoreApi() => _instance;

  final http.Client _client = http.Client();
  static String _cookie = '';
  static String _storeApiNonce = '';

  /// ---------- Helpers ----------
  Uri _u(String path, [Map<String, String>? qp]) {
    final base = Uri.parse(
      StoreConfig.baseUrl.endsWith('/')
          ? StoreConfig.baseUrl
          : '${StoreConfig.baseUrl}/',
    );
    final resolved = base.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    return qp == null ? resolved : resolved.replace(queryParameters: qp);
  }

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Origin': StoreConfig.baseUrl,
      'Referer': StoreConfig.baseUrl,
      'Accept-Language': 'fa-IR,fa;q=0.9,en-US;q=0.8,en;q=0.7',
      'User-Agent': 'EramYadakFlutter/1.0',
    };
    if (_cookie.isNotEmpty) map['Cookie'] = _cookie;
    if (_storeApiNonce.isNotEmpty) map['X-WC-Store-API-Nonce'] = _storeApiNonce;
    return map;
  }

  void _captureAuthFromResponse(http.BaseResponse r) {
    try {
      final setCookieRaw = r.headers['set-cookie'];
      if (setCookieRaw?.isNotEmpty ?? false) {
        final parts = setCookieRaw!.split(RegExp(r',(?=\s*\w+=)'));
        final keep = <String>[];
        for (final p in parts) {
          final kv = p.split(';').first.trim();
          if (kv.isEmpty) continue;
          final name = kv.split('=').first;
          if (name.startsWith('wp_woocommerce_session_') ||
              name == 'woocommerce_items_in_cart' ||
              name == 'woocommerce_cart_hash') {
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
            final keyName = k.split('=').first;
            existing.removeWhere((e) => e.split('=').first == keyName);
            existing.add(k);
          }
          _cookie = existing.join('; ');
        }
      }

      String? nonce;
      r.headers.forEach((k, v) {
        final key = k.toLowerCase();
        if (key == 'x-wc-store-api-nonce' || key == 'x-wp-nonce') nonce = v;
      });
      if (nonce?.isNotEmpty ?? false) _storeApiNonce = nonce!;
      debugPrint('StoreApi: cookie="$_cookie" nonce="$_storeApiNonce"');
    } catch (e) {
      debugPrint('StoreApi: captureAuthFromResponse failed: $e');
    }
  }

  Future<http.Response> _get(Uri url) async {
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(StoreConfig.requestTimeout);
    _captureAuthFromResponse(resp);
    return resp;
  }

  Future<http.Response> _post(Uri url, Object? body) async {
    final payload = body is String ? body : json.encode(body);
    final resp = await _client
        .post(url, headers: _headers, body: payload)
        .timeout(StoreConfig.requestTimeout);
    _captureAuthFromResponse(resp);
    return resp;
  }

  Future<http.Response> _postWithHeaders(
    Uri url,
    Object? body, {
    Map<String, String>? extraHeaders,
  }) async {
    final payload = body is String ? body : json.encode(body);
    final headers = Map<String, String>.from(_headers);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final resp = await _client
        .post(url, headers: headers, body: payload)
        .timeout(StoreConfig.requestTimeout);
    _captureAuthFromResponse(resp);
    return resp;
  }

  /// ---------- Public APIs ----------

  Future<void> ensureSession() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200)
      throw HttpException('Cart init ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> getCart() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200)
      throw HttpException('Cart ${r.statusCode}: ${r.body}');
    return json.decode(r.body) as Map<String, dynamic>;
  }

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
    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }
    if (r.statusCode != 200 && r.statusCode != 201)
      throw HttpException('Add item ${r.statusCode}: ${r.body}');
  }

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
    if (r.statusCode != 200)
      throw HttpException('Update qty ${r.statusCode}: ${r.body}');
  }

  Future<void> removeItem({required String itemKey}) async {
    Future<http.Response> _doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/remove-item'), {'key': itemKey});
    var r = await _doPost();
    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }
    if (r.statusCode != 200)
      throw HttpException('Remove ${r.statusCode}: ${r.body}');
  }

  Future<void> clearCart() async {
    Future<http.Response> _doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/clear'), {});
    var r = await _doPost();
    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await _doPost();
    }
    if (r.statusCode != 200)
      throw HttpException('Clear cart ${r.statusCode}: ${r.body}');
  }

  /// ثبت سفارش چک با مدیریت 401/403
  Future<Map<String, dynamic>> createOrderCheque({
    Map<String, dynamic>? billing,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? meta,
  }) async {
    final uri = _u('/wp-json/eram/v1/create-order-cheque');
    final payload = {
      if (billing != null) 'billing': billing,
      if (items != null) 'line_items': items,
      if (shipping != null) 'shipping': shipping,
      if (meta != null) 'meta': meta,
    };

    if (kDebugMode) {
      debugPrint('StoreApi.createOrderCheque: payload = ${json.encode(payload)}');
    }

    // اینجا کلید اختصاصی از config.dart خوانده و هدر ساخته می‌شود
    final extra = <String, String>{};
    final secret = (AppConfig.eramKey ?? '').trim();
    if (secret.isNotEmpty) extra['X-ERAM-KEY'] = secret;

    Future<http.Response> send() =>
        _postWithHeaders(uri, payload, extraHeaders: extra);

    var resp = await send();
    if (kDebugMode) {
      debugPrint('StoreApi.createOrderCheque: response.statusCode = ${resp.statusCode}');
      debugPrint('StoreApi.createOrderCheque: response.body = ${resp.body}');
    }
    
    if (resp.statusCode == 401 ||
        resp.statusCode == 403 ||
        resp.body.toLowerCase().contains('rest_forbidden')) {
      await ensureSession();
      resp = await send();
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = json.decode(resp.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : {'success': true, 'raw': decoded};
    }

    String message = resp.body;
    try {
      final parsed = json.decode(resp.body);
      if (parsed is Map && parsed['error'] != null)
        message = parsed['error'].toString();
      else if (parsed is Map && parsed['message'] != null)
        message = parsed['message'].toString();
    } catch (_) {}

    throw HttpException(
      'createOrderCheque failed ${resp.statusCode}: $message',
    );
  }

  /// دسترسی به cookie و nonce
  String get cookieString => _cookie;
  String get nonce => _storeApiNonce;
}
