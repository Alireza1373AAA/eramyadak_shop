class AppConfig {
  static const String baseUrl = "https://eramyadak.com";

  // WooCommerce REST API keys
  static const String wcKey = "ck_d048a902be76b829500a62cfada0aedf6b8ff2e3";
  static const String wcSecret = "cs_34ca1d5da0c8db0ad5a6fc5ed66078451ec16851";
}

/// تنظیمات مربوط به سرویس پیامکی برای ارسال کد تایید.
class SmsConfig {
  /// آدرس پایهٔ سرویس پیامکی «فراز اس‌ام‌اس».
  static const String baseUrl = 'https://ippanel.com/services.jspd';

  /// نام کاربری وب‌سرویس.
  static const String username = '09031703862';

  /// کلمه عبور وب‌سرویس.
  static const String password = 'Faraz@1818341352';

  /// کلید API در صورت نیاز برخی سناریوها.
  static const String apiKey =
      'YTAzODdiNzYtNmM0NC00YzY1LTg5NmMtMTg2NmM1NTcyZWNmMDUxMTBlMDJmYzBlYzYyNTk1Y2UyNDI1ODVjOTRjYzg=';

  /// شماره اختصاصی ارسال‌کننده پیامک.
  static const String sender = '983000505';

  /// قالب پیامک تأیید هویت. جای‌گذاری {code} با کد تایید انجام می‌شود.
  static const String messageTemplate = 'کد تایید شما: {code}';

  /// مدت‌زمان اعتبار کد تایید.
  static const Duration otpLifetime = Duration(minutes: 2);

  /// تولید متن پیامک از روی قالب تعیین‌شده.
  static String buildMessage(String code) =>
      messageTemplate.replaceAll('{code}', code);
}
