import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'faraz_sms_client.dart';
import 'sms_exception.dart';

class SmsNotAllowedException implements Exception {
  final String phone;
  const SmsNotAllowedException(this.phone);
  @override
  String toString() => 'SmsNotAllowedException: $phone is not allowed';
}

class SmsCheckFailedException implements Exception {
  final String message;
  const SmsCheckFailedException(this.message);
  @override
  String toString() => 'SmsCheckFailedException: $message';
}

class SmsService {
  SmsService({FarazSmsClient? client, http.Client? httpClient})
    : _client = client ?? FarazSmsClient(),
      _http = httpClient ?? http.Client();

  final FarazSmsClient _client;
  final http.Client _http;

  Future<void> sendVerificationCode({
    required String phone,
    required String code,
  }) async {
    final toPlus = SmsConfig.normalizePhoneToPlus98(phone);

    final allowed = await _checkPhoneAllowedOnServer(toPlus);
    if (!allowed) throw SmsNotAllowedException(toPlus);

    try {
      await _client.sendPattern(recipientPlus98: toPlus, codeValue: code);
      if (kDebugMode) print('[SmsService] sent SMS to $toPlus (code=$code)');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _checkPhoneAllowedOnServer(String phonePlus98) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/wp-json/eram/v1/check-phone');

      final resp = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'phone': phonePlus98}),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body is Map && body.containsKey('allowed')) {
          return body['allowed'] == true;
        } else {
          throw SmsCheckFailedException('Invalid JSON response');
        }
      } else if (resp.statusCode == 400) {
        return false;
      } else {
        throw SmsCheckFailedException(
          'Unexpected status ${resp.statusCode} - ${resp.body}',
        );
      }
    } on TimeoutException {
      throw SmsCheckFailedException('Timeout while checking phone whitelist');
    } catch (e) {
      throw SmsCheckFailedException(e.toString());
    }
  }

  void dispose() {
    _client.close();
    _http.close();
  }
}
