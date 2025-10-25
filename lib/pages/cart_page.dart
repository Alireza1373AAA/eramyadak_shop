// lib/pages/cart_page.dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/store_api.dart' as store;
import '../utils/price.dart';

/* ======================== تنظیمات زرین‌پال ======================== */
class ZarinpalConfig {
  static const String merchantId = '9e9ca42a-aec4-4b39-b584-56f8b3286276';
  static const String callbackUrl = 'https://your-site.example/zp-callback';
  static const String description = 'پرداخت سفارش از اپلیکیشن';
}

/* ======================== سرویس زرین‌پال ======================== */
class ZarinpalService {
  static const String _requestUrl =
      'https://api.zarinpal.com/pg/v4/payment/request.json';
  static const String _verifyUrl =
      'https://api.zarinpal.com/pg/v4/payment/verify.json';
  static String startPayUrl(String authority) =>
      'https://www.zarinpal.com/pg/StartPay/$authority';
  static const _headers = {'Content-Type': 'application/json'};

  static Future<String> requestPayment({
    required int amountRial,
    String description = ZarinpalConfig.description,
    String callbackUrl = ZarinpalConfig.callbackUrl,
  }) async {
    final body = {
      'merchant_id': ZarinpalConfig.merchantId,
      'amount': amountRial,
      'description': description,
      'callback_url': callbackUrl,
    };
    final res = await http.post(
      Uri.parse(_requestUrl),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final authority = data['data']?['authority']?.toString() ?? '';
    if (authority.isEmpty) {
      final msg =
          (data['errors']?['message'] ??
                  data['data']?['message'] ??
                  'authority دریافت نشد')
              .toString();
      throw Exception(msg);
    }
    return authority;
  }

  static Future<ZarinpalVerifyResult> verifyPayment({
    required int amountRial,
    required String authority,
  }) async {
    final body = {
      'merchant_id': ZarinpalConfig.merchantId,
      'amount': amountRial,
      'authority': authority,
    };
    final res = await http.post(
      Uri.parse(_verifyUrl),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Verify HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final code = data['data']?['code'] as int?;
    return ZarinpalVerifyResult(
      ok: code == 100 || code == 101,
      code: code,
      refId: data['data']?['ref_id']?.toString(),
      message:
          (data['data']?['message'] ?? data['errors']?['message'] ?? 'نامشخص')
              .toString(),
      raw: data,
    );
  }
}

class ZarinpalVerifyResult {
  final bool ok;
  final int? code;
  final String? refId;
  final String message;
  final Map<String, dynamic> raw;
  ZarinpalVerifyResult({
    required this.ok,
    required this.code,
    required this.refId,
    required this.message,
    required this.raw,
  });
}

/* ======================== صفحه سبد خرید ======================== */
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final store.StoreApi api = store.StoreApi();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _cart;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await api.ensureSession();
      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await api.getCart();
      if (!mounted) return;
      setState(() {
        _cart = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _items =>
      (_cart?['items'] as List?) ??
      (_cart?['line_items'] as List?) ??
      (_cart?['cart_items'] as List?) ??
      const [];

  // مقادیر resilient از کلیدهای متداول
  int get _totalToman {
    final t = _cart?['totals'] as Map<String, dynamic>?;
    final v =
        t?['total_price'] ??
        t?['total'] ??
        t?['grand_total'] ??
        _cart?['total'] ??
        _cart?['cart_total'] ??
        _cart?['payable'];
    return Price.toToman(v);
  }

  int _readToman(dynamic v) => Price.toToman(v);

  void _goToShop() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سبد خرید من'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadCart,
              icon: const Icon(Icons.refresh),
              tooltip: 'به‌روزرسانی سبد',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
              const Text('خطا در دریافت سبد'),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadCart,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text('سبد خرید شما خالی است.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _goToShop,
                icon: const Icon(Icons.storefront),
                label: const Text('ادامه خرید'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCart,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final x = _items[i] as Map<String, dynamic>;
                final itemKey =
                    (x['key'] ?? x['item_key'] ?? x['cart_item_key'] ?? '')
                        .toString();
                final name =
                    (x['name'] ??
                            x['product_name'] ??
                            (x['product'] is Map
                                ? x['product']['name']
                                : null) ??
                            '')
                        .toString();
                final qty = ((x['quantity'] ?? x['qty'] ?? 1) as num).round();

                String? imageUrl;
                final images = x['images'];
                if (images is List && images.isNotEmpty) {
                  final first = images.first;
                  if (first is Map && first['src'] is String)
                    imageUrl = first['src'] as String;
                  if (first is String) imageUrl = first;
                } else if (x['image'] is String) {
                  imageUrl = x['image'];
                }

                // تلاش برای خواندن line total از کلیدهای مختلف
                final lineRaw =
                    x['totals']?['line_total'] ??
                    x['line_total'] ??
                    x['total'] ??
                    x['prices']?['price'] ??
                    x['price'];
                final lineToman = _readToman(lineRaw);

                return Dismissible(
                  key: ValueKey(itemKey.isEmpty ? '$i' : itemKey),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('حذف از سبد'),
                            content: Text('«$name» حذف شود؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('انصراف'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => _remove(itemKey),
                  child: Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl == null
                            ? const Icon(Icons.shopping_bag_outlined, size: 40)
                            : Image.network(
                                imageUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported),
                              ),
                      ),
                      title: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        Price.formatToman(lineToman),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 1
                                ? () => _updateQty(itemKey, qty - 1)
                                : null,
                          ),
                          Text('$qty'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _updateQty(itemKey, qty + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(itemKey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // خلاصه و دکمه‌ها
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _totalRow('مبلغ قابل پرداخت:', _totalToman),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.storefront),
                        label: const Text('ادامه خرید'),
                        onPressed: _goToShop,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('پرداخت با زرین‌پال'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _openZarinpalCheckout,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openWebsiteCheckout,
                  icon: const Icon(Icons.web),
                  label: const Text('تسویه حساب در وب‌سایت'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String title, int toman, {bool neg = false}) {
    final txt = Price.formatToman(toman, withLabel: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            neg ? '- $txt' : txt,
            style: TextStyle(
              color: neg ? Colors.red : null,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQty(String key, int qty) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await api.updateItemQty(itemKey: key, quantity: qty);
      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(String key) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await api.removeItem(itemKey: key);
      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openZarinpalCheckout() async {
    final amountRial = _totalToman * 10; // زرین‌پال ریال می‌خواهد
    if (amountRial < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ پرداخت باید حداقل ۱,۰۰۰ ریال باشد')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authority = await ZarinpalService.requestPayment(
        amountRial: amountRial,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // بستن اسپینر

      final result = await Navigator.push<ZarinpalVerifyResult?>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ZarinpalWebViewPage(authority: authority, amount: amountRial),
        ),
      );

      if (result == null) return;

      if (result.ok) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('پرداخت موفق'),
            content: Text(
              'پرداخت با موفقیت انجام شد.\nکد رهگیری: ${result.refId ?? '-'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشه'),
              ),
            ],
          ),
        );
        await _loadCart();
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('پرداخت ناموفق'),
            content: Text('کد: ${result.code ?? '-'}\n${result.message}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('باشه'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در پرداخت: $e')));
    }
  }

  void _openWebsiteCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutWebView(initialCookie: api.cookieString),
      ),
    );
  }
}

/* ======================== WebView پرداخت زرین‌پال ======================== */
class ZarinpalWebViewPage extends StatefulWidget {
  const ZarinpalWebViewPage({
    super.key,
    required this.authority,
    required this.amount,
  });
  final String authority;
  final int amount; // ریال

  @override
  State<ZarinpalWebViewPage> createState() => _ZarinpalWebViewPageState();
}

class _ZarinpalWebViewPageState extends State<ZarinpalWebViewPage> {
  late final WebViewController _controller;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100.0),
          onPageFinished: (_) => setState(() => _progress = 0),
          onNavigationRequest: (req) async {
            final url = req.url;

            if (url.startsWith(ZarinpalConfig.callbackUrl)) {
              final uri = Uri.parse(url);
              final status =
                  uri.queryParameters['Status'] ??
                  uri.queryParameters['status'];
              final authority =
                  uri.queryParameters['Authority'] ??
                  uri.queryParameters['authority'] ??
                  widget.authority;

              if ((status ?? '').toLowerCase() == 'ok') {
                try {
                  final verify = await ZarinpalService.verifyPayment(
                    amountRial: widget.amount,
                    authority: authority,
                  );
                  if (!mounted) return NavigationDecision.prevent;
                  Navigator.of(context).pop<ZarinpalVerifyResult>(verify);
                } catch (e) {
                  if (!mounted) return NavigationDecision.prevent;
                  Navigator.of(context).pop<ZarinpalVerifyResult>(
                    ZarinpalVerifyResult(
                      ok: false,
                      code: null,
                      refId: null,
                      message: 'خطا در Verify: $e',
                      raw: const {},
                    ),
                  );
                }
              } else {
                if (mounted) {
                  Navigator.of(context).pop<ZarinpalVerifyResult>(
                    ZarinpalVerifyResult(
                      ok: false,
                      code: null,
                      refId: null,
                      message: 'کاربر پرداخت را لغو کرد',
                      raw: const {},
                    ),
                  );
                }
              }
              return NavigationDecision.prevent;
            }

            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _controller.loadRequest(
      Uri.parse(ZarinpalService.startPayUrl(widget.authority)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پرداخت زرین‌پال'),
          actions: [
            IconButton(
              icon: const Icon(Icons.verified),
              tooltip: 'بررسی پرداخت',
              onPressed: () async {
                try {
                  final verify = await ZarinpalService.verifyPayment(
                    amountRial: widget.amount,
                    authority: widget.authority,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop<ZarinpalVerifyResult>(verify);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطا در Verify: $e')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress > 0
                ? LinearProgressIndicator(value: _progress)
                : const SizedBox.shrink(),
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}

/* ======================== Checkout وب‌سایت (اختیاری) ======================== */
class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key, required this.initialCookie});
  final String initialCookie;

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;
  double _progress = 0.0;
  static const String checkoutPath = '/checkout/';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100.0),
          onPageFinished: (_) => setState(() => _progress = 0),
          onNavigationRequest: (req) {
            final url = req.url;
            if (!req.isMainFrame) {
              _controller.loadRequest(Uri.parse(url));
              return NavigationDecision.prevent;
            }
            if (url.startsWith(store.StoreConfig.baseUrl))
              return NavigationDecision.navigate;
            if (url.startsWith('http://') || url.startsWith('https://'))
              return NavigationDecision.navigate;
            return NavigationDecision.prevent;
          },
        ),
      );

    final checkoutUrl = Uri.parse('${store.StoreConfig.baseUrl}$checkoutPath');
    if (widget.initialCookie.isNotEmpty) {
      _controller.loadRequest(
        checkoutUrl,
        headers: {'Cookie': widget.initialCookie},
      );
    } else {
      _controller.loadRequest(checkoutUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسویه حساب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress > 0
                ? LinearProgressIndicator(value: _progress)
                : const SizedBox.shrink(),
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
