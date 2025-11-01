import '../config.dart';
import 'sms_exception.dart';
import 'faraz_sms_client.dart';

class SmsService {
  SmsService({FarazSmsClient? client})
      : _client = client ?? FarazSmsClient();

  final FarazSmsClient _client;

  /// ارسال کد تایید به شماره [phone] با استفاده از قالب پیامکی تنظیم‌شده در [SmsConfig].
  ///
  /// در صورت موفقیت شناسهٔ پیامک ارسال‌شده بازگردانده می‌شود.
  Future<int> sendVerificationCode({
    required String phone,
    required String code,
  }) async {
    if (SmsConfig.username.isEmpty ||
        SmsConfig.password.isEmpty ||
        SmsConfig.sender.isEmpty) {
      throw SmsException(
        'مقادیر نام کاربری، کلمه عبور یا شماره فرستنده در SmsConfig مقداردهی نشده‌اند.',
      );
    }

    final message = SmsConfig.buildMessage(code);
    final parsed = await _client.send(
      username: SmsConfig.username,
      password: SmsConfig.password,
      recipientNumbers: [phone],
      message: message,
      sender: SmsConfig.sender,
    );
    return parsed.messageIds.first;
  }

  void close() => _client.close();
}
