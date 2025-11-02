import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'sms_exception.dart';

/// پاسخ برگشتی از وب‌سرویس «فراز اس‌ام‌اس».
class FarazSmsResponse {
  FarazSmsResponse({
    required this.type,
    required this.message,
    this.code,
    List<int>? messageIds,
  }) : messageIds = messageIds ?? const [];

  /// مقدار فیلد وضعیت در پاسخ که معمولاً "success" یا "error" است.
  final String type;

  /// متن پیام برگشتی از سرویس.
  final String message;

  /// کد خطای احتمالی در پاسخ.
  final int? code;

  /// شناسه‌های پیامک استخراج شده از پاسخ.
  final List<int> messageIds;

  /// مشخص می‌کند که پاسخ موفقیت‌آمیز بوده است یا خیر.
  bool get isSuccess {
    final normalized = type.toLowerCase();
    if (normalized == 'success' || normalized == 'ok') {
      return true;
    }
    if (code != null) {
      // طبق مستندات فراز، وضعیت‌های 200 و 0 نشان‌دهنده موفقیت هستند.
      return code == 200 || code == 0;
    }
    return false;
  }

  /// ساخت نمونه از روی نگاشت JSON.
  factory FarazSmsResponse.fromJson(Map<String, dynamic> json) {
    final ids = <int>{};

    String? type = _readString(json, ['type', 'result', 'status']);
    String? message =
        _readString(json, ['message', 'error', 'description', 'detail']);
    int? code = _readInt(json, ['code', 'status']);

    void addDynamicIds(dynamic value) {
      if (value is List) {
        for (final item in value) {
          addDynamicIds(item);
        }
      } else if (value is num) {
        ids.add(value.toInt());
      } else if (value is String) {
        final matches = RegExp(r'\d+').allMatches(value);
        for (final match in matches) {
          final parsed = int.tryParse(match.group(0)!);
          if (parsed != null) {
            ids.add(parsed);
          }
        }
      }
    }

    void inspectMap(Map<String, dynamic> map) {
      addDynamicIds(map['ids']);
      addDynamicIds(map['messageids']);
      addDynamicIds(map['message_ids']);
      addDynamicIds(map['messageIds']);
      addDynamicIds(map['batch_id']);
      addDynamicIds(map['messageid']);
      addDynamicIds(map['message_id']);

      type ??= _readString(map, ['type', 'result', 'status']);
      message ??=
          _readString(map, ['message', 'error', 'description', 'detail']);
      code ??= _readInt(map, ['code', 'status']);

      for (final entry in map.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          inspectMap(value);
        }
      }
    }

    inspectMap(json);

    if (type == null) {
      type = code == 200 || code == 0 ? 'success' : 'error';
    }

    message ??= '';

    if (ids.isEmpty && message!.isNotEmpty) {
      // تلاش نهایی برای یافتن شناسه در متن پیام برگشتی.
      addDynamicIds(message);
    }

    return FarazSmsResponse(
      type: type!,
      message: message!,
      code: code,
      messageIds: ids.toList(growable: false),
    );
  }

  static String? _readString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static int? _readInt(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

/// کلاینت ساده برای ارسال پیام از طریق درگاه «فراز اس‌ام‌اس».
class FarazSmsClient {
  FarazSmsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FarazSmsResponse> send({
    required String username,
    required String password,
    required List<String> recipientNumbers,
    required String message,
    required String sender,
  }) async {
    if (recipientNumbers.isEmpty) {
      throw SmsException('هیچ شماره‌ای برای ارسال پیامک ارائه نشده است.');
    }

    final uri = Uri.parse(SmsConfig.baseUrl);
    late http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uname': username,
          'pass': password,
          'from': sender,
          'message': message,
          'to': recipientNumbers,
          'op': 'send',
        }),
      );
    } on http.ClientException catch (error) {
      throw SmsException('ارتباط با سرویس پیامکی برقرار نشد: ${error.message}');
    }

    if (response.statusCode != 200) {
      throw SmsException(
        'پاسخ نامعتبر از سرویس پیامکی دریافت شد.',
        statusCode: response.statusCode,
      );
    }

    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) {
      throw SmsException('پاسخ خالی از سرویس پیامکی دریافت شد.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      final normalized = body.toLowerCase();
      if (normalized == 'deny') {
        throw SmsException(
          'درگاه پیامکی دسترسی را رد کرد (deny). لطفاً نام کاربری، کلمه عبور یا محدودیت آی‌پی حساب فراز اس‌ام‌اس را بررسی کنید.',
        );
      }
      throw SmsException('پاسخ نامعتبر از سرویس پیامکی دریافت شد: $body');
    }

    if (decoded is! Map<String, dynamic>) {
      throw SmsException('ساختار پاسخ دریافتی پشتیبانی نمی‌شود: $body');
    }

    final parsed = FarazSmsResponse.fromJson(decoded);
    if (!parsed.isSuccess) {
      final buffer = StringBuffer('ارسال پیامک با خطا مواجه شد');
      if (parsed.code != null) {
        buffer.write(' (کد ${parsed.code})');
      }
      if (parsed.message.isNotEmpty) {
        buffer.write(': ${parsed.message}');
      }
      throw SmsException(buffer.toString());
    }

    if (parsed.messageIds.isEmpty) {
      throw SmsException('پاسخ سرویس حاوی شناسه پیامک نبود.');
    }

    return parsed;
  }

  void close() => _client.close();
}
