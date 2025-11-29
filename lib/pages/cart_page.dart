// lib/pages/cart_page.dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/store_api.dart' as store;
import '../services/auth_storage.dart';
import '../utils/price.dart';

/// ======================== تنظیمات زرین‌پال ========================
class ZarinpalConfig {
  static const String merchantId = '9e9ca42a-aec4-4b39-b584-56f8b3286276';
  static const String callbackUrl = 'https://your-site.example/zp-callback';
  static const String description = 'پرداخت سفارش از اپلیکیشن';
}

/// ======================== سرویس زرین‌پال ========================
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
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
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
    if (res.statusCode != 200) throw Exception('Verify HTTP ${res.statusCode}');
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

/// ======================== صفحه سبد خرید ========================
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

  int get _totalToman {
    final t = _cart?['totals'] as Map<String, dynamic>?;
    final v =
        t?['total_price'] ??
        t?['total'] ??
        t?['grand_total'] ??
        _cart?['total'] ??
        0;
    return Price.toToman(v);
  }

  int _readToman(dynamic v) => Price.toToman(v);

  int? _readUnitToman(Map<String, dynamic> item) {
    final possible = [
      item['unit_price'],
      item['price'],
      item['prices']?['price'],
      item['price_per_unit'],
      item['single_price'],
    ];
    for (final p in possible) {
      final t = Price.toTomanNullable(p);
      if (t != null) return t;
    }
    return null;
  }

  int? _readCartonToman(Map<String, dynamic> item) {
    final possible = [
      item['carton_price'],
      item['price_per_carton'],
      item['carton']?['price'],
      item['pack_price'],
    ];
    for (final p in possible) {
      final t = Price.toTomanNullable(p);
      if (t != null) return t;
    }
    return null;
  }

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
    if (_error != null) return _buildError();
    if (_items.isEmpty) return _buildEmpty();
    return _buildCart();
  }

  Widget _buildError() {
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
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadCart, child: const Text('تلاش مجدد')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
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

  Widget _buildCart() {
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
              itemBuilder: _buildCartItem,
            ),
          ),
          _buildCartSummary(),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, int i) {
    final x = _items[i] as Map<String, dynamic>;
    final itemKey = (x['key'] ?? x['item_key'] ?? x['cart_item_key'] ?? '')
        .toString();
    final name =
        (x['name'] ??
                x['product_name'] ??
                (x['product'] is Map ? x['product']['name'] : null) ??
                '')
            .toString();
    final qty = ((x['quantity'] ?? x['qty'] ?? 1) as num).round();

    String? imageUrl;
    final images = x['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] is String) imageUrl = first['src'];
      if (first is String) imageUrl = first;
    } else if (x['image'] is String)
      imageUrl = x['image'];

    final lineRaw =
        x['totals']?['line_total'] ??
        x['line_total'] ??
        x['total'] ??
        x['prices']?['price'] ??
        x['price'];
    final lineToman = _readToman(lineRaw);

    final unitToman = _readUnitToman(x);
    final cartonToman = _readCartonToman(x);

    Widget subtitleWidget() {
      final children = <Widget>[];
      if (unitToman != null)
        children.add(
          Text(
            'قیمت تکی: ${Price.formatToman(unitToman)}',
            style: const TextStyle(color: Colors.grey),
          ),
        );
      if (cartonToman != null)
        children.add(
          Text(
            'قیمت کارتن: ${Price.formatToman(cartonToman)}',
            style: const TextStyle(color: Colors.grey),
          ),
        );
      children.add(
        Text(
          Price.formatToman(lineToman),
          style: const TextStyle(color: Colors.grey),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Dismissible(
      key: ValueKey(itemKey.isNotEmpty ? itemKey : i),
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
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: subtitleWidget(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: qty > 1 ? () => _updateQty(itemKey, qty - 1) : null,
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
  }

  Widget _buildCartSummary() {
    return Container(
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
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openZarinpalCheckout,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('پرداخت با چک (اپ)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openChequeCheckout,
                ),
              ),
            ],
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
    final amountRial = _totalToman * 10;
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
      Navigator.of(context).pop();

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

  // ------------------ پرداخت با چک (اپ) ------------------
  Future<void> _openChequeCheckout() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('سبد خرید شما خالی است.')));
      return;
    }

    // استفاده از اطلاعات ثبت‌شده کاربر
    final profile = await AuthStorage.loadProfile();
    if (profile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا ثبت‌نام کنید.')),
      );
      return;
    }

    // ساخت billing از اطلاعات پروفایل
    final billing = {
      'first_name': profile.firstName,
      'last_name': profile.lastName,
      'phone': profile.phone,
      'address_1': profile.address,
      'city': profile.city,
      'postcode': profile.postalCode,
    };

    // ساخت payload آیتم‌ها
    final itemsPayload = <Map<String, dynamic>>[];
    
    if (kDebugMode) {
      debugPrint('CartPage: _items length = ${_items.length}');
      debugPrint('CartPage: _items = $_items');
    }
    
    for (final raw in _items) {
      try {
        final map = (raw is Map<String, dynamic>)
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        
        if (kDebugMode) {
          debugPrint('CartPage: processing item raw keys = ${map.keys.toList()}');
          debugPrint('CartPage: item raw = ${jsonEncode(map)}');
        }
        
        // استخراج product_id از فیلدهای مختلف ممکن
        // WooCommerce Store API: 'id' is the product_id in cart items
        int? productId;
        
        // Try product_id first
        final rawProductId = map['product_id'];
        if (rawProductId != null) {
          productId = (rawProductId is int) 
              ? rawProductId 
              : int.tryParse(rawProductId.toString());
          if (kDebugMode) {
            debugPrint('CartPage: found product_id = $productId');
          }
        }
        
        // Then try 'id' field (WooCommerce Store API uses this)
        if (productId == null || productId == 0) {
          final rawId = map['id'];
          if (rawId != null) {
            productId = (rawId is int) 
                ? rawId 
                : int.tryParse(rawId.toString());
            if (kDebugMode) {
              debugPrint('CartPage: found id = $productId (type: ${rawId.runtimeType})');
            }
          }
        }
        
        // Try nested product object
        if (productId == null || productId == 0) {
          if (map['product'] is Map) {
            final rawProdId = map['product']['id'];
            if (rawProdId != null) {
              productId = (rawProdId is int) 
                  ? rawProdId 
                  : int.tryParse(rawProdId.toString());
              if (kDebugMode) {
                debugPrint('CartPage: found product.id = $productId');
              }
            }
          }
        }
        
        final quantity = (map['quantity'] ?? map['qty'] ?? 1);
        final quantityInt = (quantity is int) ? quantity : int.tryParse(quantity.toString()) ?? 1;
        
        // استخراج variation_id
        int? variationId;
        final rawVariation = map['variation_id'];
        if (rawVariation != null && rawVariation != 0) {
          variationId = (rawVariation is int) 
              ? rawVariation 
              : int.tryParse(rawVariation.toString());
        }
        if ((variationId == null || variationId == 0) && map['variation'] is Map) {
          final rawVarId = map['variation']['id'];
          if (rawVarId != null) {
            variationId = (rawVarId is int) 
                ? rawVarId 
                : int.tryParse(rawVarId.toString());
          }
        }
        
        // استخراج نام محصول از فیلدهای مختلف ممکن
        final productName =
            (map['name'] ??
                    map['product_name'] ??
                    (map['product'] is Map ? map['product']['name'] : null) ??
                    '')
                .toString();
        
        // استخراج قیمت از فیلدهای مختلف ممکن
        final price = map['prices']?['price'] ?? 
                      map['price'] ?? 
                      map['totals']?['line_total'] ??
                      map['line_total'];

        if (kDebugMode) {
          debugPrint('CartPage: extracted - productId=$productId, quantity=$quantityInt, name=$productName');
        }

        if (productId == null || productId == 0) {
          if (kDebugMode) {
            debugPrint('CartPage: skipping item - no valid product_id found');
          }
          continue;
        }

        final it = <String, dynamic>{
          'product_id': productId,
          'quantity': quantityInt,
        };
        if (variationId != null && variationId != 0) {
          it['variation_id'] = variationId;
        }
        if (productName.isNotEmpty) it['name'] = productName;
        if (price != null) it['price'] = price.toString();
        
        itemsPayload.add(it);
        
        if (kDebugMode) {
          debugPrint('CartPage: added item to payload = ${jsonEncode(it)}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CartPage: error parsing item: $e');
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('CartPage: final itemsPayload = ${jsonEncode(itemsPayload)}');
    }

    if (kDebugMode) {
      debugPrint('CartPage: itemsPayload = ${jsonEncode(itemsPayload)}');
      debugPrint('CartPage: billing = ${jsonEncode(billing)}');
      debugPrint('CartPage: totalToman = $_totalToman');
    }

    // loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await api.createOrderCheque(
        billing: billing,
        items: itemsPayload,
        total: (_totalToman * 10).toString(), // ارسال مبلغ کل به ریال
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      if (res['success'] == true) {
        final id = res['order_id'] ?? res['id'] ?? res['orderId'];
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('سفارش ثبت شد'),
            content: Text(
              'سفارش شما با موفقیت ثبت شد.\nشماره سفارش: ${id ?? '-'}',
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
        final err =
            res['error'] ??
            res['message'] ??
            res['raw']?.toString() ??
            'خطای ناشناخته';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا: $err')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در ایجاد سفارش: $e')));
    }
  }

  String? _guessEmailFromCart() {
    try {
      for (final x in _items) {
        if (x is Map && x['customer_email'] != null)
          return x['customer_email'].toString();
      }
    } catch (_) {}
    return null;
  }

  String? _guessPhoneFromCart() {
    try {
      for (final x in _items) {
        if (x is Map && x['customer_phone'] != null)
          return x['customer_phone'].toString();
      }
    } catch (_) {}
    return null;
  }
}

/// ======================== ویجت فرم پرداخت با چک ========================
class _ChequeForm extends StatefulWidget {
  final String? initialEmail;
  final String? initialPhone;
  const _ChequeForm({this.initialEmail, this.initialPhone});

  @override
  State<_ChequeForm> createState() => _ChequeFormState();
}

class _ChequeFormState extends State<_ChequeForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'IR');
  final _stateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) _emailCtrl.text = widget.initialEmail!;
    if (widget.initialPhone != null) _phoneCtrl.text = widget.initialPhone!;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postcodeCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final billing = {
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address_1': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'postcode': _postcodeCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
    };
    Navigator.of(context).pop(billing);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اطلاعات صورتحساب برای پرداخت با چک',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'نام (الزامی)'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'نام را وارد کنید'
                      : null,
                ),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'نام خانوادگی'),
                ),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'ایمیل'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'تلفن (الزامی)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'تلفن را وارد کنید'
                      : null,
                ),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'آدرس'),
                ),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(labelText: 'شهر'),
                ),
                TextFormField(
                  controller: _postcodeCtrl,
                  decoration: const InputDecoration(labelText: 'کدپستی'),
                ),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(labelText: 'کشور'),
                ),
                TextFormField(
                  controller: _stateCtrl,
                  decoration: const InputDecoration(labelText: 'استان/شهرستان'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('ثبت و ارسال'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ======================== WebView پرداخت زرین‌پال ========================
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
          onNavigationRequest: _handleNavigation,
          onWebResourceError: (err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('WebView Error: ${err.description}')),
            );
          },
        ),
      );
    _controller.loadRequest(
      Uri.parse(ZarinpalService.startPayUrl(widget.authority)),
    );
  }

  Future<NavigationDecision> _handleNavigation(NavigationRequest req) async {
    final url = req.url;
    if (url.startsWith(ZarinpalConfig.callbackUrl)) {
      final uri = Uri.parse(url);
      final status =
          uri.queryParameters['Status'] ?? uri.queryParameters['status'];
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

    return (url.startsWith('http://') || url.startsWith('https://'))
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
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
