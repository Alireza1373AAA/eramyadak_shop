import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:eramyadak_shop/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _cookieStorageKey = 'eram_store_api_cookie';
  static const String _nonceStorageKey = 'eram_store_api_nonce';
  static const String _cartBackupStorageKey = 'eram_store_api_cart_backup';
  bool _sessionRestored = false;
  bool _restoringCartBackup = false;
  Future<void>? _sessionRestoreFuture;
  Future<Map<String, dynamic>?>? _cartBackupRestoreFuture;

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

  Future<void> _restoreStoredSession() async {
    if (_sessionRestored) return;
    final pending = _sessionRestoreFuture;
    if (pending != null) return pending;

    final future = () async {
      try {
        final sp = await SharedPreferences.getInstance();
        _cookie = sp.getString(_cookieStorageKey) ?? _cookie;
        _storeApiNonce = sp.getString(_nonceStorageKey) ?? _storeApiNonce;
      } catch (e) {
        debugPrint('StoreApi: restore session failed: $e');
      } finally {
        _sessionRestored = true;
        _sessionRestoreFuture = null;
      }
    }();

    _sessionRestoreFuture = future;
    return future;
  }

  Future<void> _persistSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (_cookie.isNotEmpty) {
        await sp.setString(_cookieStorageKey, _cookie);
      }
      if (_storeApiNonce.isNotEmpty) {
        await sp.setString(_nonceStorageKey, _storeApiNonce);
      }
    } catch (e) {
      debugPrint('StoreApi: persist session failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _readCartBackup() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cartBackupStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('StoreApi: read cart backup failed: $e');
    }
    return null;
  }

  Future<void> _persistCartBackup(Map<String, dynamic> cart) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (_cartItems(cart).isEmpty) {
        await sp.remove(_cartBackupStorageKey);
      } else {
        await sp.setString(_cartBackupStorageKey, json.encode(cart));
      }
    } catch (e) {
      debugPrint('StoreApi: persist cart backup failed: $e');
    }
  }

  Future<void> _clearCartBackup() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_cartBackupStorageKey);
    } catch (e) {
      debugPrint('StoreApi: clear cart backup failed: $e');
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  dynamic _nestedValue(Map<dynamic, dynamic> item, String key, String nested) {
    final value = item[key];
    if (value is Map) return value[nested];
    return null;
  }

  Map<String, String>? _cartVariationAttributes(Map<dynamic, dynamic> item) {
    final raw = item['variation'];
    final attrs = <String, String>{};

    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final attribute =
            (entry['attribute'] ?? entry['name'] ?? entry['slug'] ?? '')
                .toString();
        final value = (entry['value'] ?? entry['raw_value'] ?? '').toString();
        if (attribute.isNotEmpty && value.isNotEmpty) attrs[attribute] = value;
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        final name = key.toString();
        final val = value?.toString() ?? '';
        if (name != 'id' && name != 'variation_id' && val.isNotEmpty) {
          attrs[name] = val;
        }
      });
    }

    return attrs.isEmpty ? null : attrs;
  }

  Map<String, dynamic>? _cartLineForRestore(dynamic item) {
    if (item is! Map) return null;

    final productId = _asInt(
      item['product_id'] ?? item['id'] ?? _nestedValue(item, 'product', 'id'),
    );
    if (productId == null || productId <= 0) return null;

    final quantity = _asInt(item['quantity'] ?? item['qty']) ?? 1;
    final variationId = _asInt(
      item['variation_id'] ??
          _nestedValue(item, 'variation', 'id') ??
          _nestedValue(item, 'variation', 'variation_id'),
    );
    final attributes = _cartVariationAttributes(item);

    return {
      'productId': productId,
      'quantity': quantity < 1 ? 1 : quantity,
      if (variationId != null && variationId > 0) 'variationId': variationId,
      if (attributes != null) 'attributes': attributes,
    };
  }

  Future<void> _captureAuthFromResponse(http.BaseResponse r) async {
    try {
      var changed = false;
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
          final nextCookie = existing.join('; ');
          if (nextCookie != _cookie) {
            _cookie = nextCookie;
            changed = true;
          }
        }
      }

      String? nonce;
      r.headers.forEach((k, v) {
        final key = k.toLowerCase();
        if (key == 'x-wc-store-api-nonce' || key == 'x-wp-nonce') nonce = v;
      });
      if (nonce?.isNotEmpty ?? false) {
        if (nonce != _storeApiNonce) {
          _storeApiNonce = nonce!;
          changed = true;
        }
      }
      if (changed) await _persistSession();
      debugPrint('StoreApi: cookie="$_cookie" nonce="$_storeApiNonce"');
    } catch (e) {
      debugPrint('StoreApi: captureAuthFromResponse failed: $e');
    }
  }

  Future<http.Response> _get(Uri url) async {
    await _restoreStoredSession();
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(StoreConfig.requestTimeout);
    await _captureAuthFromResponse(resp);
    return resp;
  }

  Future<http.Response> _post(Uri url, Object? body) async {
    await _restoreStoredSession();
    final payload = body is String ? body : json.encode(body);
    final resp = await _client
        .post(url, headers: _headers, body: payload)
        .timeout(StoreConfig.requestTimeout);
    await _captureAuthFromResponse(resp);
    return resp;
  }

  Future<http.Response> _postWithHeaders(
    Uri url,
    Object? body, {
    Map<String, String>? extraHeaders,
  }) async {
    await _restoreStoredSession();
    final payload = body is String ? body : json.encode(body);
    final headers = Map<String, String>.from(_headers);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final resp = await _client
        .post(url, headers: headers, body: payload)
        .timeout(StoreConfig.requestTimeout);
    await _captureAuthFromResponse(resp);
    return resp;
  }

  Future<Map<String, dynamic>> _fetchCartFromServer() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200) {
      throw HttpException('Cart ${r.statusCode}: ${r.body}');
    }
    final decoded = json.decode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw HttpException('Cart response is not an object');
  }

  Future<http.Response> _addCartLineToServer({
    required int productId,
    int quantity = 1,
    int? variationId,
    Map<String, String>? attributes,
  }) async {
    Future<http.Response> doPost() =>
        _post(_u('/wp-json/wc/store/v1/cart/add-item'), {
          'id': productId,
          'quantity': quantity,
          if (variationId != null) 'variation_id': variationId,
          if (attributes != null && attributes.isNotEmpty)
            'variation': attributes.entries
                .map((e) => {'attribute': e.key, 'value': e.value})
                .toList(),
        });

    var r = await doPost();
    if (r.statusCode == 401 ||
        r.body.contains('woocommerce_rest_missing_nonce')) {
      await ensureSession();
      r = await doPost();
    }
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw HttpException('Add item ${r.statusCode}: ${r.body}');
    }
    return r;
  }

  Future<void> _syncCartBackupFromServer({bool clearWhenEmpty = true}) async {
    try {
      final cart = await _fetchCartFromServer();
      if (_cartItems(cart).isEmpty) {
        if (clearWhenEmpty) await _clearCartBackup();
      } else {
        await _persistCartBackup(cart);
      }
    } catch (e) {
      debugPrint('StoreApi: sync cart backup failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _restoreCartBackupToServer() async {
    final pending = _cartBackupRestoreFuture;
    if (pending != null) return pending;

    final future = _restoreCartBackupToServerOnce();
    _cartBackupRestoreFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_cartBackupRestoreFuture, future)) {
        _cartBackupRestoreFuture = null;
      }
    }
  }

  Future<Map<String, dynamic>?> _restoreCartBackupToServerOnce() async {
    if (_restoringCartBackup) return null;

    final backup = await _readCartBackup();
    if (backup == null || _cartItems(backup).isEmpty) return null;

    _restoringCartBackup = true;
    try {
      var restoredAny = false;
      for (final item in _cartItems(backup)) {
        final line = _cartLineForRestore(item);
        if (line == null) continue;

        try {
          await _addCartLineToServer(
            productId: line['productId'] as int,
            quantity: line['quantity'] as int,
            variationId: line['variationId'] as int?,
            attributes: line['attributes'] as Map<String, String>?,
          );
          restoredAny = true;
        } catch (e) {
          debugPrint('StoreApi: restore cart item failed: $e');
        }
      }

      if (restoredAny) {
        final restored = await _fetchCartFromServer();
        if (_cartItems(restored).isNotEmpty) {
          await _persistCartBackup(restored);
          return restored;
        }
      }

      return backup;
    } finally {
      _restoringCartBackup = false;
    }
  }

  Future<void> _restoreCartBackupIfCurrentCartIsEmpty() async {
    if (_restoringCartBackup) return;
    try {
      final current = await _fetchCartFromServer();
      if (_cartItems(current).isEmpty) {
        await _restoreCartBackupToServer();
      } else {
        await _persistCartBackup(current);
      }
    } catch (e) {
      debugPrint('StoreApi: pre-add cart restore check failed: $e');
    }
  }

  /// ---------- Public APIs ----------

  Future<void> ensureSession() async {
    final r = await _get(_u('/wp-json/wc/store/v1/cart'));
    if (r.statusCode != 200)
      throw HttpException('Cart init ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> getCart() async {
    final cart = await _fetchCartFromServer();
    if (_cartItems(cart).isNotEmpty) {
      await _persistCartBackup(cart);
      return cart;
    }

    final restored = await _restoreCartBackupToServer();
    return restored ?? cart;
  }

  Future<void> addToCart({
    required int productId,
    int quantity = 1,
    int? variationId,
    Map<String, String>? attributes,
  }) async {
    await _restoreCartBackupIfCurrentCartIsEmpty();
    await _addCartLineToServer(
      productId: productId,
      quantity: quantity,
      variationId: variationId,
      attributes: attributes,
    );
    await _syncCartBackupFromServer(clearWhenEmpty: false);
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
    await _syncCartBackupFromServer();
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
    await _syncCartBackupFromServer();
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
    await _clearCartBackup();
  }

  /// ثبت سفارش چک با مدیریت 401/403
  List<dynamic> _cartItems(Map<String, dynamic> cart) =>
      (cart['items'] as List?) ??
      (cart['line_items'] as List?) ??
      (cart['cart_items'] as List?) ??
      const [];

  String _cartItemKey(dynamic item) {
    if (item is! Map) return '';
    return (item['key'] ?? item['item_key'] ?? item['cart_item_key'] ?? '')
        .toString();
  }

  Future<void> clearCartAfterOrder() async {
    try {
      await clearCart();
      return;
    } catch (e) {
      debugPrint('StoreApi.clearCartAfterOrder: clear failed: $e');
    }

    final cart = await getCart();
    final items = _cartItems(cart);
    if (items.isEmpty) return;

    Object? lastError;
    var removedAny = false;
    for (final item in items) {
      final key = _cartItemKey(item);
      if (key.isEmpty) continue;

      try {
        await removeItem(itemKey: key);
        removedAny = true;
      } catch (e) {
        lastError = e;
        debugPrint('StoreApi.clearCartAfterOrder: remove failed: $e');
      }
    }

    final refreshed = await getCart();
    if (_cartItems(refreshed).isEmpty) {
      await _clearCartBackup();
      return;
    }

    throw HttpException(
      'Order created but cart could not be cleared: ${lastError ?? (removedAny ? 'items remain' : 'missing item keys')}',
    );
  }

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
      debugPrint(
          'StoreApi.createOrderCheque: payload = ${json.encode(payload)}');
    }

    // اینجا کلید اختصاصی از config.dart خوانده و هدر ساخته می‌شود
    final extra = <String, String>{};
    final secret = (AppConfig.eramKey ?? '').trim();
    if (secret.isNotEmpty) extra['X-ERAM-KEY'] = secret;

    Future<http.Response> send() =>
        _postWithHeaders(uri, payload, extraHeaders: extra);

    var resp = await send();
    if (kDebugMode) {
      debugPrint(
          'StoreApi.createOrderCheque: response.statusCode = ${resp.statusCode}');
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
