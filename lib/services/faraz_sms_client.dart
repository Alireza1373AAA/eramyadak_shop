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

  /// مقدار فیلد `type` در پاسخ که معمولاً "success" یا "error" است.
  final String type;

  /// متن پیام برگشتی از سرویس.
  final String message;

  /// کد خطای احتمالی در پاسخ.
  final int? code;

  /// شناسه‌های پیامک استخراج شده از پاسخ.
  final List<int> messageIds;

  /// مشخص می‌کند که پاسخ موفقیت‌آمیز بوده است یا خیر.
  bool get isSuccess => type.toLowerCase() == 'success';

  /// ساخت نمونه از روی نگاشت JSON.
  factory FarazSmsResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'error';
    final message = json['message']?.toString() ?? '';
    final codeValue = json['code'];
    final code = codeValue is num ? codeValue.toInt() : null;

    final ids = <int>{};

    void addDynamicIds(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is num) {
            ids.add(item.toInt());
          } else if (item is String) {
            final parsed = int.tryParse(item);
            if (parsed != null) {
              ids.add(parsed);
            }
          }
        }
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

    addDynamicIds(json['ids']);
    addDynamicIds(json['messageids']);
    addDynamicIds(json['message_ids']);

    final details = json['details'];
    if (details is Map<String, dynamic>) {
      addDynamicIds(details['ids']);
      addDynamicIds(details['messageids']);
    }

    if (ids.isEmpty) {
      final normalized = message.toLowerCase();
      if (normalized.contains('id') || message.contains('شناسه')) {
        addDynamicIds(message);
      }
    }

    return FarazSmsResponse(
      type: type,
      message: message,
      code: code,
      messageIds: ids.toList(growable: false),
    );
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
