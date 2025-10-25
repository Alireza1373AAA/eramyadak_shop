// lib/pages/checkout_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/store_api.dart' as store; // برای StoreConfig و API
import 'cart_page.dart'; // صفحهٔ بومی سبد

class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key, required this.initialCookie});
  final String initialCookie;

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;
  double _progress = 0.0;
  static final Uri _checkoutUri = Uri.parse(
    '${store.StoreConfig.baseUrl}/checkout/',
  );

  // --- سبد خرید (برای badge و پنل خلاصه)
  final store.StoreApi _api = store.StoreApi();
  bool _cartLoading = false;
  String? _cartError;
  Map<String, dynamic>? _cart;

  List<dynamic> get _items => (_cart?['items'] as List?) ?? const [];
  int get _cartCount {
    int n = 0;
    for (final it in _items) {
      final q = (it is Map) ? ((it['quantity'] ?? 0) as num?)?.round() ?? 0 : 0;
      n += q;
    }
    return n;
  }

  int _moneyToInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.round();
    if (v is String) {
      final s = v.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      return double.tryParse(s)?.round() ?? 0;
    }
    if (v is Map) return _moneyToInt(v['amount']);
    return 0;
  }

  int get _total => _moneyToInt(_cart?['totals']?['total_price']);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 0);
            // بعد از هر بار بارگذاری صفحه، تلاش کن سبد را تازه کنی
            _refreshCart(silent: true);
          },
          onNavigationRequest: (req) {
            // فقط http/https
            final uri = Uri.parse(req.url);
            final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
            if (!isHttp) return NavigationDecision.prevent;

            // target=_blank → داخل همین WebView باز شود
            if (req.isMainFrame == false) {
              _controller.loadRequest(uri);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('خطا: ${err.description}')));
          },
        ),
      );

    // کوکی سبد را به درخواست اولیه بده
    if (widget.initialCookie.isNotEmpty) {
      _controller.loadRequest(
        _checkoutUri,
        headers: {'Cookie': widget.initialCookie},
      );
    } else {
      _controller.loadRequest(_checkoutUri);
    }

    // نشست API (برای خواندن سبد) و سپس دریافت سبد
    _bootstrapCart();
  }

  Future<void> _bootstrapCart() async {
    try {
      await _api.ensureSession();
    } catch (_) {}
    await _refreshCart(silent: true);
  }

  Future<void> _refreshCart({bool silent = false}) async {
    if (!mounted || _cartLoading) return;
    setState(() {
      _cartLoading = true;
      if (!silent) _cartError = null;
    });
    try {
      final c = await _api.getCart();
      if (!mounted) return;
      setState(() {
        _cart = c;
        _cartLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartError = e.toString();
        _cartLoading = false;
      });
    }
  }

  void _openCartPage() async {
    // رفتن به صفحه بومی سبد خرید
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
    // برگشت از صفحهٔ سبد → تازه‌سازی سبد و صفحهٔ checkout
    await _refreshCart();
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final badgeCount = _cartCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسویه حساب'),
          actions: [
            // آیکن سبد با Badge
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Stack(
                alignment: Alignment.topLeft,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'مشاهده سبد',
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: _showCartSheet,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _controller.reload();
                _refreshCart(silent: true);
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress > 0
                ? LinearProgressIndicator(value: _progress)
                : const SizedBox.shrink(),
          ),
        ),

        // دکمهٔ شناور «رفتن به سبد خرید»
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.shopping_basket_outlined),
          label: const Text('سبد خرید'),
          onPressed: _openCartPage,
        ),

        body: WillPopScope(
          onWillPop: () async {
            if (await _controller.canGoBack()) {
              _controller.goBack();
              return false;
            }
            return true;
          },
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }

  // نمایش BottomSheet خلاصهٔ سبد
  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        if (_cartLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_cartError != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 8),
                Text(
                  _cartError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _refreshCart();
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        }
        if (_items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('سبد خرید شما خالی است.')),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // لیست اقلام
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (_, i) {
                      final x = _items[i] as Map<String, dynamic>;
                      final name = (x['name'] ?? '').toString();
                      final qty = ((x['quantity'] ?? 1) as num).round();
                      final lineTotal = _moneyToInt(x['totals']?['line_total']);

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('تعداد: $qty'),
                        trailing: Text(
                          '${_formatToman(lineTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'جمع قابل پرداخت:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _formatToman(_total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('به‌روزرسانی سبد'),
                        onPressed: () {
                          _refreshCart();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text('رفتن به سبد خرید'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openCartPage();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatToman(int amount) {
    // فرمت ساده بدون وابستگی به intl در این فایل
    final s = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$s تومان';
  }
}
