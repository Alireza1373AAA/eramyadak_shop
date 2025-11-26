class StoreConfig {
  // آدرس‌ها و تنظیمات پایه
  static const String baseUrl = 'https://eramyadak.com';
  static const String apiBase = '$baseUrl/wp-json/wc/v3';
  static const int productsPageSize = 20;
  static const bool apiReturnsRial = true;
  static const String currencyLabel = 'تومان';
  static const bool showPersianDigits = true;

  // 🧮 توابع تبدیل و فرمت قیمت

  /// تبدیل مقدار خام API به تومان
  /// ورودی می‌تواند int یا double باشد (num)، خروجی int خواهد بود.
  static int toToman(num raw) {
    if (!apiReturnsRial) return raw.round();
    // اگر API مقدار را ریال می‌دهد، تبدیل به تومان (هر 10 ریال = 1 تومان)
    return (raw / 10).round();
  }

  /// تبدیل مقدار Nullable به تومان (اگر null، null برگردان)
  static int? toTomanNullable(num? raw) => raw == null ? null : toToman(raw);

  /// تبدیل تومان به ریال
  static int tomanToRial(int toman) => toman * 10;

  /// جداکننده هزارگان ساده، مقاوم در برابر اعداد منفی
  static String thousandSep(int n) {
    final isNegative = n < 0;
    var s = (isNegative ? -n : n).toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final posFromRight = s.length - i;
      buffer.write(s[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buffer.write(',');
      }
    }
    final out = buffer.toString();
    return isNegative ? '-$out' : out;
  }

  /// تبدیل اعداد انگلیسی به فارسی
  static String toFaDigits(String s) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return s.replaceAllMapped(RegExp(r'\d'), (m) {
      final d = int.parse(m.group(0)!);
      return fa[d];
    });
  }

  /// فرمت نهایی تومان با برچسب واحد
  static String formatTomanInt(int? toman, {bool withLabel = true}) {
    if (toman == null) return '';
    String out = thousandSep(toman);
    if (showPersianDigits) out = toFaDigits(out);
    return withLabel ? '$out $currencyLabel' : out;
  }
}
