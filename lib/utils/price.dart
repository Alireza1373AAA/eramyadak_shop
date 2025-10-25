// lib/utils/price.dart
import '../data/store_config.dart';

class Price {
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.round();
    if (v is String) {
      final s = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(s)?.round() ?? 0;
    }
    if (v is Map) return _toInt(v['amount'] ?? v['value']);
    return 0;
  }

  /// خام API → تومان
  static int toToman(dynamic apiValue) {
    final raw = _toInt(apiValue);
    return StoreConfig.apiReturnsRial ? (raw / 10).round() : raw;
  }

  /// فرمت تومان با برچسب
  static String formatToman(dynamic apiValue, {bool withLabel = true}) {
    final n = toToman(apiValue);
    final s = n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final out = StoreConfig.showPersianDigits
        ? s.replaceAllMapped(
            RegExp(r'\d'),
            (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)],
          )
        : s;
    return withLabel ? '$out ${StoreConfig.currencyLabel}' : out;
  }
}
