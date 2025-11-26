// lib/config.dart

/// =======================================
/// تنظیمات اصلی فروشگاه و WooCommerce
/// =======================================
class AppConfig {
  /// دامنه سایت (بدون / انتهایی)
  static const String baseUrl = "https://eramyadak.com";

  /// کلیدهای REST API ووکامرس
  /// (برای محصول‌ها، سبد، ایجاد سفارش معمولی و ... لازم است)
  static const String wcKey = "ck_d048a902be76b829500a62cfada0aedf6b8ff2e3";
  static const String wcSecret = "cs_34ca1d5da0c8db0ad5a6fc5ed66078451ec16851";

  /// -------------------------------------------
  /// کلید اختصاصی endpoint پرداخت با چک
  /// -------------------------------------------
  /// این secret باید دقیقاً با همان مقدار در افزونه PHP مطابقت داشته باشد.
  static const String? eramKey = "f92KpA73xQ9Zb61LmC4tR8vN2wH0sD5J";

  /// آدرس endpoint سفارشی چک
  static String get chequeOrderUrl =>
      "$baseUrl/wp-json/eram/v1/create-order-cheque";
}

/// =======================================
/// تنظیمات سامانه پیامکی (IPPanel – Edge API)
/// =======================================
class SmsConfig {
  /// API Key از پنل — همان رشته‌ای که باید داخل Authorization ارسال شود.
  static const String apiKey =
      "YTA0NjdjZDMtZjY4MS00MjVhLWIxMjYtZTZhYTc0NDljMTI4MTIwNDg1Zjg1ZDU3Mzg3ZmE2YWVjNjYwZTEwN2ZkY2U=";

  /// Endpoint رسمی (Edge API)
  static const String sendUrl = "https://edge.ippanel.com/v1/api/send";

  /// کد پترن تعریف‌شده در پنل
  static const String patternCode = "7aptiju9b23c2ia";

  /// نام متغیر تعریف‌شده در پترن
  static const String patternVar = "code";

  /// شماره ارسال‌کنندهٔ متصل به پترن (باید با +98 باشد)
  static const String sender = "+983000505";

  /// مدت اعتبار کد تأیید
  static const Duration otpLifetime = Duration(minutes: 2);

  /// استانداردسازی شماره موبایل → خروجی همیشه: +989xxxxxxxxx
  static String normalizePhoneToPlus98(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (d.startsWith('0098')) {
      d = '+98${d.substring(4)}';
    } else if (d.startsWith('98') && !d.startsWith('+98')) {
      d = '+98${d.substring(2)}';
    } else if (RegExp(r'^09\d{9}$').hasMatch(d)) {
      d = '+98${d.substring(1)}';
    } else if (RegExp(r'^9\d{9}$').hasMatch(d)) {
      d = '+98$d';
    }

    if (!RegExp(r'^\+989\d{9}$').hasMatch(d)) {
      throw FormatException('شماره موبایل معتبر نیست');
    }
    return d;
  }
}
