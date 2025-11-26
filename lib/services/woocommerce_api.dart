import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

final _cookieJar = CookieJar();

final Dio dio = Dio(
  BaseOptions(
    baseUrl: 'https://eramyadak.com',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ),
);

/// مقداردهی اولیه Dio و CookieManager
void initHttp() {
  dio.interceptors.add(CookieManager(_cookieJar));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.next(options),
      onResponse: (response, handler) => handler.next(response),
      onError: (DioError e, handler) => handler.next(e),
    ),
  );
}

/// فقط وب/PWA: ارسال کوکی‌ها
void enableWebCredentialsIfNeeded() {
  if (kIsWeb) {
    dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
  }
}

/// Cache برای nonce
String? _cachedNonce;
DateTime? _nonceAt;

/// دریافت nonce از Store API
Future<String> _getStoreNonce() async {
  if (_cachedNonce != null &&
      _nonceAt != null &&
      DateTime.now().difference(_nonceAt!) < const Duration(minutes: 8)) {
    return _cachedNonce!;
  }

  final res = await dio.get(
    '/wp-json/eram/v1/store-nonce',
    options: Options(extra: {'withCredentials': true}),
  );

  if (res.statusCode == 200 && res.data is Map && res.data['nonce'] != null) {
    _cachedNonce = res.data['nonce'] as String;
    _nonceAt = DateTime.now();
    return _cachedNonce!;
  }

  throw Exception('دریافت نانس ناموفق بود: ${res.statusCode}');
}

/// ریست دستی nonce
void clearStoreNonce() {
  _cachedNonce = null;
  _nonceAt = null;
}

/// اجرای یک درخواست POST امن با nonce
Future<Response> _postWithNonce(String path, Map<String, dynamic> data) async {
  Future<Response> _send(String nonce) {
    return dio.post(
      path,
      data: data,
      options: Options(
        headers: {'X-WC-Store-API-Nonce': nonce},
        extra: {'withCredentials': true},
      ),
    );
  }

  try {
    final nonce = await _getStoreNonce();
    return await _send(nonce);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401 ||
        (e.response?.data.toString().contains(
              'woocommerce_rest_missing_nonce',
            ) ??
            false)) {
      clearStoreNonce();
      final fresh = await _getStoreNonce();
      return await _send(fresh);
    }
    rethrow;
  }
}

/// افزودن محصول به سبد
Future<void> addToCart(int productId, {int qty = 1}) async {
  await _postWithNonce('/wp-json/wc/store/v1/cart/add-item', {
    'id': productId,
    'quantity': qty,
  });
}

/// دریافت وضعیت فعلی سبد
Future<Map<String, dynamic>> getCart() async {
  try {
    final res = await dio.get(
      '/wp-json/wc/store/v1/cart',
      options: Options(extra: {'withCredentials': true}),
    );

    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }

    throw Exception('دریافت سبد ناموفق بود: ${res.statusCode}');
  } catch (e) {
    throw Exception('خطا در دریافت سبد: $e');
  }
}

/// حذف یک آیتم از سبد
Future<void> removeItem(String itemKey) async {
  await _postWithNonce('/wp-json/wc/store/v1/cart/remove-item', {
    'key': itemKey,
  });
}

/// پاک کردن کل سبد
Future<void> clearCart() async {
  await _postWithNonce('/wp-json/wc/store/v1/cart/clear', {});
}
