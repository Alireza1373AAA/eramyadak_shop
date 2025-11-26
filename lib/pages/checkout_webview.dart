// lib/pages/checkout_webview.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../data/store_api.dart';

class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key, required this.initialCookie});
  final String initialCookie;

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;
  double _progress = 0.0;
  final StoreApi _api = StoreApi();
  bool _loadingCart = false;
  Map<String, dynamic>? _cart;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: (_) => _refreshCart(),
          onNavigationRequest: (req) {
            final uri = Uri.parse(req.url);
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            if (!req.isMainFrame) {
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

    final checkoutUri = Uri.parse('${AppConfig.baseUrl}/checkout/');
    if (widget.initialCookie.isNotEmpty) {
      _controller.loadRequest(
        checkoutUri,
        headers: {'Cookie': widget.initialCookie},
      );
    } else {
      _controller.loadRequest(checkoutUri);
    }

    _bootstrapCart();
  }

  Future<void> _bootstrapCart() async {
    try {
      await _api.ensureSession();
      await _refreshCart();
    } catch (_) {}
  }

  Future<void> _refreshCart() async {
    if (_loadingCart) return;
    setState(() => _loadingCart = true);

    try {
      final cart = await _api.getCart();
      if (!mounted) return;
      setState(() {
        _cart = cart;
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingCart = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسویه حساب'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress > 0
              ? LinearProgressIndicator(value: _progress)
              : const SizedBox.shrink(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
