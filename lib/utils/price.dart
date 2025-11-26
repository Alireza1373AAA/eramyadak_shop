// lib/utils/price.dart

class Price {
  Price._();

  /// Convert a nullable/various-shaped value to nullable *toman* integer.
  /// Returns null when value cannot be parsed.
  static int? toTomanNullable(dynamic v) {
    if (v == null) return null;

    // If value is already a number
    if (v is int) return v;
    if (v is double) return v.round();

    // If value is a string, strip non-digits and parse
    if (v is String) {
      final s = v.replaceAll(RegExp('[^0-9]'), '');
      if (s.isEmpty) return null;
      try {
        return int.parse(s);
      } catch (_) {
        return null;
      }
    }

    // If value is a map/object try common keys
    if (v is Map) {
      // common numeric keys
      final keys = [
        'amount',
        'value',
        'price',
        'price_in_toman',
        'price_in_rial',
      ];
      for (final k in keys) {
        if (v.containsKey(k) && v[k] != null) {
          final parsed = toTomanNullable(v[k]);
          if (parsed != null) {
            // if key suggests rial explicitly, convert
            if (k.toLowerCase().contains('rial')) return (parsed / 10).round();
            return parsed;
          }
        }
      }

      // currency hint
      final currency = (v['currency'] ?? v['unit'] ?? v['currency_code'])
          ?.toString()
          .toLowerCase();
      if (currency != null) {
        if (currency.contains('rial') ||
            currency.contains('irr') ||
            currency.contains('ریال')) {
          // find an amount in the map
          final cand = v['amount'] ?? v['price'] ?? v['value'];
          final parsed = toTomanNullable(cand);
          if (parsed != null) return (parsed / 10).round();
        }
        if (currency.contains('toman') || currency.contains('تومان')) {
          final cand = v['amount'] ?? v['price'] ?? v['value'];
          final parsed = toTomanNullable(cand);
          if (parsed != null) return parsed;
        }
      }

      // nested object: try common nested fields
      for (final k in v.keys) {
        final parsed = toTomanNullable(v[k]);
        if (parsed != null) return parsed;
      }

      return null;
    }

    // Unhandled type
    return null;
  }

  /// Convert various-shaped value to *toman* integer.
  /// Returns 0 when value is null/unparseable (convenience wrapper).
  static int toToman(dynamic v) => toTomanNullable(v) ?? 0;

  /// Format toman integer using thousands separators and optional label.
  /// Example: Price.formatToman(1234000) -> "1,234,000" (EN digits)
  /// The app in the repo uses western digits; if you want Persian digits,
  /// replace digits using a mapping or use intl package.
  static String formatToman(int toman, {bool withLabel = false}) {
    final s = _thousandFormat(toman);
    return withLabel ? '$s تومان' : s;
  }

  static String _thousandFormat(int n) {
    final s = n.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (m) => ',');
  }
}
