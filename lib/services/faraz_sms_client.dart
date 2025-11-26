// lib/services/faraz_sms_client.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:eramyadak_shop/config.dart';
import 'package:eramyadak_shop/services/sms_exception.dart';

class FarazSmsClient {
  FarazSmsClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Try header formats in order. Adjust to your provider's docs.
  List<String> _authFormats(String key) => [
    'AccessKey $key', // common for ippanel/faraz
    'Bearer $key',
    key, // raw key as fallback
  ];

  Future<void> sendPattern({
    required String recipientPlus98,
    required String codeValue,
  }) async {
    final url = Uri.parse(SmsConfig.sendUrl);

    // basic validation number
    final reg = RegExp(r'^\+989\d{9}$');
    if (!reg.hasMatch(recipientPlus98)) {
      throw SmsException('شماره نامعتبر: $recipientPlus98');
    }

    final bodyMap = {
      "sending_type": "pattern",
      "from_number": SmsConfig.sender,
      "code": SmsConfig.patternCode,
      "recipients": [recipientPlus98],
      "params": {SmsConfig.patternVar: codeValue},
    };

    http.Response? res;
    Exception? lastError;

    for (final auth in _authFormats(SmsConfig.apiKey)) {
      try {
        res = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': auth,
              },
              body: utf8.encode(jsonEncode(bodyMap)),
            )
            .timeout(const Duration(seconds: 12));
      } catch (e) {
        lastError = e as Exception;
        continue;
      }

      // اگر پاسخ 401 بود، تلاش کن با فرمت بعدی
      if (res.statusCode == 401) {
        lastError = SmsException(
          'Invalid token (status 401), tried auth="$auth"',
          statusCode: res.statusCode,
          body: res.body,
        );
        continue;
      }

      // اگر 200/201 بود و body بررسی شود
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final j = jsonDecode(res.body);
          // اگر API یک فیلد status:false برمی‌گرداند، treat as error
          if (j is Map && (j['status'] == false || j['success'] == false)) {
            throw SmsException('ارسال ناموفق: ${j['message'] ?? j}');
          }
        } catch (e) {
          // اگر json نشد، اما status http 200 است، قبول می‌کنیم (یا لاگ کن)
        }
        return; // موفق شدیم
      }

      // سایر وضعیت‌ها را به عنوان خطا برمی‌گردان
      String msg = res.body;
      try {
        final j = jsonDecode(res.body);
        msg = j['message']?.toString() ?? j['error']?.toString() ?? msg;
      } catch (_) {}
      throw SmsException(
        'خطا در ارسال پیامک: $msg',
        statusCode: res.statusCode,
        body: res.body,
      );
    }

    // اگر به اینجا رسیدیم یعنی همه فرمت‌های auth امتحان شدند ولی موفق نبود
    if (lastError != null) {
      throw SmsException('ارسال پیامک ناموفق: ${lastError.toString()}');
    }
    throw SmsException('ارسال پیامک ناموفق (unknown reason)');
  }

  void close() => _client.close();
}
