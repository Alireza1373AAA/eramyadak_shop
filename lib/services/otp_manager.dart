// lib/services/otp_manager.dart
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:eramyadak_shop/config.dart';
import 'package:eramyadak_shop/services/sms_service.dart';
import 'package:eramyadak_shop/services/sms_exception.dart';

enum OtpValidationError {
  notRequested,
  phoneMismatch,
  expired,
  codeMismatch,
  notAllowed, // شماره مجاز نیست (برای استفاده داخلی)
}

class OtpManager {
  OtpManager({SmsService? smsService}) : _sms = smsService ?? SmsService();

  final SmsService _sms;
  final _rnd = Random();

  String? _lastPhonePlus98;
  String? _lastCode;
  DateTime? _expiresAt;

  /// زمان باقی‌مانده
  Duration? get remaining {
    if (_expiresAt == null) return null;
    final d = _expiresAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// --- ارسال کد + چک شماره در وردپرس ---
  /// در صورت مشکل شبکه یا عدم مجاز بودن شماره `SmsException` پرتاب می‌شود
  Future<void> sendCode(String phone) async {
    final normalized = SmsConfig.normalizePhoneToPlus98(phone);

    // 1) چک شماره از وردپرس (با timeout و محافظت)
    bool allowed = true;
    try {
      allowed = await _checkPhoneAllowed(normalized);
    } catch (e, st) {
      // اگر خطای شبکه/سرور داشتیم، لاگ می‌کنیم و پیش‌فرض را اجازه می‌دهیم
      // (اگر می‌خواهی در صورت خطا شماره بلاک شود، این رفتار را تغییر بده)
      debugPrint(
        'OtpManager: checkPhoneAllowed failed, allowing by default: $e\n$st',
      );
      allowed = true;
    }

    if (!allowed) {
      // به جای throw enum، SmsException می‌اندازیم تا UI آن را هندل کند
      throw SmsException('شماره شما مجاز به استفاده از این سرویس نیست');
    }

    // 2) تولید کد و ارسال پیامک (با هندل خطا)
    final code = _generateCode();
    try {
      await _sms.sendVerificationCode(phone: normalized, code: code);
    } catch (e) {
      // اگر ارسال پیامک خطا داشت، آن را تبدیل به SmsException می‌کنیم (اگر خودش SmsException بود بازپرتاب کن)
      if (e is SmsException) rethrow;
      throw SmsException('خطا در ارسال پیامک: $e');
    }

    // 3) نگهداری اطلاعات در حافظهٔ موقت
    _lastPhonePlus98 = normalized;
    _lastCode = code;
    _expiresAt = DateTime.now().add(SmsConfig.otpLifetime);
    debugPrint('OtpManager: sent code to $normalized, expires at $_expiresAt');
  }

  /// بررسی کد — در صورت موفقیت null برمی‌گرداند، در غیر این صورت یکی از OtpValidationError ها
  OtpValidationError? validate(String phone, String code) {
    if (_lastCode == null || _expiresAt == null)
      return OtpValidationError.notRequested;

    final normalized = SmsConfig.normalizePhoneToPlus98(phone);
    if (normalized != _lastPhonePlus98) return OtpValidationError.phoneMismatch;

    if (DateTime.now().isAfter(_expiresAt!)) return OtpValidationError.expired;

    if (code.trim() != _lastCode) return OtpValidationError.codeMismatch;

    // اگر کد درست بود، برای امنیت پاک‌شان کن (تا قابل‌استفادهٔ دوباره نباشه)
    _lastCode = null;
    _expiresAt = null;
    _lastPhonePlus98 = null;

    return null;
  }

  /// تولید کد ۶ رقمی
  String _generateCode() => (_rnd.nextInt(900000) + 100000).toString();

  /// تماس با وردپرس برای چک مجاز بودن شماره
  /// بازگشت true وقتی allowed == true
  /// در صورت خطای شبکه/سرور استثنا پرتاب می‌شود (بدلیل timeout یا parse)
  Future<bool> _checkPhoneAllowed(String phone) async {
    final url = Uri.parse("${AppConfig.baseUrl}/wp-json/eram/v1/check-phone");

    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        // بازگشت صریح boolean اگر موجود باشد، در غیر اینصورت true در نظر بگیر
        if (jsonBody is Map && jsonBody.containsKey("allowed")) {
          return jsonBody["allowed"] == true;
        } else {
          // پاسخ غیرمنتظره اما 200 — اجازه بدهیم تا تجربه کاربری خراب نشود
          debugPrint(
            'OtpManager: checkPhoneAllowed unexpected body: ${res.body}',
          );
          return true;
        }
      }

      // اگر 403 یا 401 یا 400 گرفتیم، منطقیست بگوییم شماره مجاز نیست (بسته به نیاز می‌توان تغییر داد)
      if (res.statusCode == 403 ||
          res.statusCode == 401 ||
          res.statusCode == 400) {
        debugPrint(
          'OtpManager: checkPhoneAllowed denied by server: ${res.statusCode} ${res.body}',
        );
        return false;
      }

      // برای سایر کدهای سرور، استثنا بزن تا caller تصمیم بگیرد (در sendCode بالا ما در صورت exception اجازه می‌دهیم)
      throw SmsException(
        'خطا در بررسی شماره: ${res.statusCode} ${res.body}',
        statusCode: res.statusCode,
        body: res.body,
      );
    } on SmsException {
      rethrow;
    } catch (e) {
      // خطای شبکه/timeout/json — پرتاب می‌کنیم تا لایه بالاتر آن را هندل کند
      throw SmsException('خطا در تماس با سرور بررسی شماره: $e');
    }
  }
}
