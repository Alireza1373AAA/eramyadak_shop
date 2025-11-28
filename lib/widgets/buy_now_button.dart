import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/store_api.dart';

class BuyNowChequeButton extends StatefulWidget {
  const BuyNowChequeButton({
    super.key,
    required this.productId,
    this.quantity = 1,
    this.variationId,
    this.label = 'خرید با چک',
    this.productName,
    this.productPrice,
  });

  final int productId;
  final int quantity;
  final int? variationId;
  final String label;
  final String? productName;
  final String? productPrice;

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
      final cartItems = cart['items'] as List?;
      
      if (kDebugMode) {
        debugPrint('BuyNowChequeButton: cart items raw = $cartItems');
      }
      
      final items = cartItems?.map<Map<String, dynamic>>((e) {
        final id = e['product_id'] ?? e['id'] ?? e['product']?['id'];
        final qty = e['quantity'] ?? e['qty'] ?? 1;
        final variation = e['variation_id'] ?? e['variation']?['id'];
        final name = e['name'] ?? e['product_name'] ?? (e['product'] is Map ? e['product']['name'] : null);
        final price = e['prices']?['price'] ?? e['price'] ?? e['totals']?['line_total'];
        
        final m = <String, dynamic>{
          'product_id': id,
          'quantity': qty,
        };
        if (variation != null) m['variation_id'] = variation;
        if (name != null) m['name'] = name.toString();
        if (price != null) m['price'] = price.toString();
        return m;
      }).toList();

      if (items == null || items.isEmpty) {
        throw Exception('سبد خرید خالی است.');
      }
      
      if (kDebugMode) {
        debugPrint('BuyNowChequeButton: items payload = $items');
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
      
      // محاسبه مجموع از سبد
      final totals = cart['totals'];
      final totalPrice = totals?['total_price'] ?? totals?['total'] ?? cart['total'];

      // ثبت سفارش چک
      final res = await _api.createOrderCheque(
        billing: billing, 
        items: items,
        total: totalPrice?.toString(),
      );

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
