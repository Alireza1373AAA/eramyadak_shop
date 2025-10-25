// lib/widgets/account_webview.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/store_api.dart' as data;
import '../data/store_config.dart' as cfg;

class AccountWebView extends StatefulWidget {
  const AccountWebView({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  State<AccountWebView> createState() => _AccountWebViewState();
}

class _AccountWebViewState extends State<AccountWebView> {
  late final WebViewController _controller;
  double _progress = 0.0;
  final data.StoreApi api = data.StoreApi();

  String get _normalizedPath =>
      widget.path.startsWith('/') ? widget.path : '/${widget.path}';
  Uri get _targetUri => Uri.parse('${cfg.StoreConfig.baseUrl}$_normalizedPath');

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
            final allow =
                url.startsWith(cfg.StoreConfig.baseUrl) ||
                url.contains('zarinpal') ||
                url.contains('idpay') ||
                url.contains('zibal') ||
                url.contains('nextpay');
            return allow
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطا در بارگذاری: ${err.description}')),
            );
          },
        ),
      );

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // ایجاد سشن و گرفتن کوکی/نانس
      await api.ensureSession();

      // اولین درخواست با کوکی سشن
      await _controller.loadRequest(
        _targetUri,
        headers: {if (api.cookieString.isNotEmpty) 'Cookie': api.cookieString},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
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
}
