// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
import '../utils/price.dart';

/// رنگ سورمه‌ای برای دکمه افزودن به سبد خرید
const Color _navyBlue = Color(0xFF1A237E);

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> p;
  final VoidCallback? onTap;
  final Future<void> Function()? onCartUpdated;

  const ProductCard({
    super.key,
    required this.p,
    this.onTap,
    this.onCartUpdated,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final store.StoreApi _api = store.StoreApi();
  bool _loading = false;
  int _quantity = 1;

  int? _readUnitToman(Map<String, dynamic> item) {
    final possible = [
      item['unit_price'],
      item['price'],
      item['prices']?['price'],
      item['price_per_unit'],
      item['single_price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
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
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  Future<void> _addToCart() async {
    setState(() => _loading = true);
    try {
      final productId = widget.p['id'];
      if (productId == null) throw Exception('Product ID is null');
      
      await _api.ensureSession();
      final id = (productId is int) ? productId : int.parse(productId.toString());
      await _api.addToCart(productId: id, quantity: _quantity);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_quantity عدد محصول به سبد خرید اضافه شد'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Reset quantity after successful add
      setState(() => _quantity = 1);
      
      if (widget.onCartUpdated != null) {
        await widget.onCartUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _incrementQuantity() {
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // اندازه‌های ریسپانسیو بر اساس عرض صفحه
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375; // iPhone SE و دیوایس‌های کوچک
    final isMediumScreen = screenWidth >= 375 && screenWidth < 414;
    
    // تنظیم اندازه‌های فونت بر اساس اندازه صفحه
    final nameFontSize = isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 13.5);
    final priceFontSize = isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0);
    final buttonFontSize = isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0);
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final paddingH = isSmallScreen ? 6.0 : (isMediumScreen ? 8.0 : 10.0);
    final paddingV = isSmallScreen ? 6.0 : (isMediumScreen ? 8.0 : 10.0);
    final spacing = isSmallScreen ? 6.0 : (isMediumScreen ? 8.0 : 10.0);
    
    final name =
        (widget.p['name'] ??
                widget.p['title'] ??
                (widget.p['product'] is Map ? widget.p['product']['name'] : null) ??
                '')
            .toString();

    String? imageUrl;
    final images = widget.p['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] is String) imageUrl = first['src'];
      if (first is String) imageUrl = first;
    } else if (widget.p['image'] is String) {
      imageUrl = widget.p['image'];
    }

    final unitToman = _readUnitToman(widget.p);
    final cartonToman = _readCartonToman(widget.p);

    Widget priceWidget() {
      final children = <Widget>[];
      if (unitToman != null) {
        children.add(
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'تکی: ${Price.formatToman(unitToman)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: priceFontSize),
            ),
          ),
        );
      }
      if (cartonToman != null) {
        children.add(
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'کارتن: ${Price.formatToman(cartonToman)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: priceFontSize),
            ),
          ),
        );
      }
      if (unitToman == null && cartonToman == null) {
        children.add(
          Text('قیمت نامشخص', style: TextStyle(color: Colors.grey, fontSize: priceFontSize)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // تصویر محصول با نسبت کمی بلندتر برای جا دادن محتوا
            AspectRatio(
              aspectRatio: isSmallScreen ? 0.95 : 1.0, // کمی بلندتر در صفحات کوچک
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, prog) {
                        if (prog == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: isSmallScreen ? 32 : 40,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(Icons.image_outlined, size: isSmallScreen ? 36 : 48),
                      ),
                    ),
            ),
            // محتوای کارت - بخش Expanded برای پر کردن فضای باقیمانده
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(paddingH, paddingV, paddingH, paddingV - 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // اسم محصول کامل - حداکثر ۴ خط با Flexible
                    Flexible(
                      flex: 3,
                      child: Text(
                        name,
                        textAlign: TextAlign.start,
                        maxLines: isSmallScreen ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing / 2),
                    // قیمت محصول
                    Flexible(
                      flex: 2,
                      child: priceWidget(),
                    ),
                    SizedBox(height: spacing / 2),
                    // کنترل تعداد (کم و زیاد کردن)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              color: Colors.grey.shade100,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // دکمه کاهش
                                InkWell(
                                  onTap: _decrementQuantity,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(50),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 6 : 10,
                                      vertical: isSmallScreen ? 4 : 6,
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: iconSize,
                                      color: _quantity > 1 ? _navyBlue : Colors.grey,
                                    ),
                                  ),
                                ),
                                // نمایش تعداد
                                Container(
                                  constraints: BoxConstraints(minWidth: isSmallScreen ? 20 : 28),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_quantity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 13 : 15,
                                      color: _navyBlue,
                                    ),
                                  ),
                                ),
                                // دکمه افزایش
                                InkWell(
                                  onTap: _incrementQuantity,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(50),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 6 : 10,
                                      vertical: isSmallScreen ? 4 : 6,
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: iconSize,
                                      color: _navyBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing / 2),
                    // دکمه افزودن به سبد با رنگ سورمه‌ای
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navyBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          minimumSize: Size(0, isSmallScreen ? 30 : 36),
                        ),
                        child: _loading
                            ? SizedBox(
                                width: isSmallScreen ? 14 : 18,
                                height: isSmallScreen ? 14 : 18,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'افزودن به سبد',
                                  style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.w600),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
