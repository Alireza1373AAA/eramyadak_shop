import 'package:flutter/material.dart';
import '../data/store_api.dart';

class BuyNowChequeButton extends StatefulWidget {
  const BuyNowChequeButton({
    super.key,
    required this.productId,
    this.quantity = 1,
    this.variationId,
    this.label = 'خرید با چک',
  });

  final int productId;
  final int quantity;
  final int? variationId;
  final String label;

  @override
  State<BuyNowChequeButton> createState() => _BuyNowChequeButtonState();
}

class _BuyNowChequeButtonState extends State<BuyNowChequeButton> {
  final StoreApi _api = StoreApi();
  bool _loading = false;

  Future<void> _buy() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await _api.ensureSession();

      // افزودن محصول به سبد
      await _api.addToCart(
        productId: widget.productId,
        quantity: widget.quantity,
        variationId: widget.variationId,
      );

      // گرفتن سبد
      final cart = await _api.getCart();
      final items = (cart['items'] as List?)?.map<Map<String, dynamic>>((e) {
        final id = e['product_id'] ?? e['product']?['id'];
        final qty = e['quantity'] ?? e['qty'] ?? 1;
        final variation = e['variation_id'] ?? e['variation']?['id'];
        final m = {'product_id': id, 'quantity': qty};
        if (variation != null) m['variation_id'] = variation;
        return m;
      }).toList();

      if (items == null || items.isEmpty) {
        throw Exception('سبد خرید خالی است.');
      }

      // اطلاعات مشتری (می‌تونی فرم واقعی بگیری)
      final billing = {
        'first_name': 'مشتری',
        'last_name': '',
        'email': 'customer@example.com',
        'phone': '09123456789',
        'address_1': '',
        'city': '',
        'postcode': '',
        'country': 'IR',
        'state': '',
      };

      // ثبت سفارش چک
      final res = await _api.createOrderCheque(billing: billing, items: items);

      final orderId = res['order_id'] ?? res['id'] ?? res['orderId'];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سفارش با موفقیت ثبت شد! شماره: $orderId')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در ثبت سفارش: $e')));
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
          : const Icon(Icons.receipt_long),
      label: Text(widget.label),
      onPressed: _loading ? null : _buy,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}
