// lib/widgets/buy_now_button.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart';

// اگر CheckoutWebView داخل cart_page.dart تعریف شده:
import '../pages/cart_page.dart'; // اگر فایل جدا دارید: import '../pages/checkout_webview.dart';

class BuyNowButton extends StatefulWidget {
  const BuyNowButton({
    super.key,
    required this.productId,
    this.quantity = 1,
    this.variationId,
    this.label = 'خرید / ادامه',
  });

  final int productId;
  final int quantity;
  final int? variationId; // برای محصول متغیر
  final String label;

  @override
  State<BuyNowButton> createState() => _BuyNowButtonState();
}

class _BuyNowButtonState extends State<BuyNowButton> {
  final StoreApi _api = StoreApi();
  bool _loading = false;

  Future<void> _buy() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await _api.ensureSession();

      // ✅ فقط از addToCart استفاده کن؛ اگر variationId داشته باشی همینجا بده
      await _api.addToCart(
        productId: widget.productId,
        quantity: widget.quantity,
        variationId: widget.variationId, // null = محصول ساده
      );

      if (!mounted) return;

      // رفتن به تسویه حساب با همان سشن/کوکی
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutWebView(initialCookie: _api.cookieString),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در افزودن به سبد: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.shopping_cart_checkout),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: _loading ? null : _buy,
    );
  }
}
