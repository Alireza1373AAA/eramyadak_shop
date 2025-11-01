import 'dart:math';

import '../config.dart';
import 'sms_exception.dart';
import 'sms_service.dart';

/// وضعیت‌های ممکن برای خطای اعتبارسنجی کد تایید.
enum OtpValidationError {
  notRequested,
  phoneMismatch,
  expired,
  codeMismatch,
}

/// مدیریت تولید و اعتبارسنجی کدهای تایید پیامکی در سطح اپ.
class OtpManager {
  OtpManager({SmsService? smsService}) : _smsService = smsService ?? SmsService();

  final SmsService _smsService;
  final Random _random = Random();

  String? _normalizedPhone;
  String? _lastCode;
  DateTime? _expiresAt;
  int? _lastMessageId;

  /// آخرین شماره‌ای که برای آن کد ارسال شده است (در قالب نرمال).
  String? get lastPhone => _normalizedPhone;

  /// زمان انقضای کد فعلی.
  DateTime? get expiresAt => _expiresAt;

  /// مدت‌زمان باقی‌مانده تا انقضای کد فعلی. در صورت انقضا، صفر برمی‌گردد.
  Duration? get remaining {
    if (_expiresAt == null) return null;
    final diff = _expiresAt!.difference(DateTime.now());
    if (diff.isNegative) {
      return Duration.zero;
    }
    return diff;
  }

  /// ارسال کد تایید جدید برای شمارهٔ [phone].
  Future<int> sendCode(String phone) async {
    final normalized = _normalizePhone(phone);
    final code = _generateCode();

    final messageId =
        await _smsService.sendVerificationCode(phone: normalized, code: code);

    _normalizedPhone = normalized;
    _lastCode = code;
    _expiresAt = DateTime.now().add(SmsConfig.otpLifetime);
    _lastMessageId = messageId;

    return messageId;
  }

  /// بررسی اعتبار کد ارسال‌شده توسط کاربر.
  OtpValidationError? validate(String phone, String code) {
    if (_lastCode == null || _expiresAt == null) {
      return OtpValidationError.notRequested;
    }

    final normalized = _normalizePhone(phone);
    if (normalized != _normalizedPhone) {
      return OtpValidationError.phoneMismatch;
    }

    if (DateTime.now().isAfter(_expiresAt!)) {
      return OtpValidationError.expired;
    }

    if (code.trim() != _lastCode) {
      return OtpValidationError.codeMismatch;
    }

    return null;
  }

  /// آخرین شناسه پیامکی که از سرویس دریافت شده است.
  int? get lastMessageId => _lastMessageId;

  /// نرمال‌سازی شماره موبایل برای ارسال به سرویس پیامکی.
  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+98')) {
      return digits.replaceFirst('+98', '0');
    }
    if (digits.startsWith('0098')) {
      return digits.replaceFirst('0098', '0');
    }
    if (digits.startsWith('98') && digits.length == 12) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 10 && digits.startsWith('9')) {
      return '0$digits';
    }
    if (RegExp(r'^09\d{9}$').hasMatch(digits)) {
      return digits;
    }
    throw SmsException('شماره موبایل واردشده معتبر نیست.');
  }

  String _generateCode() {
    final value = _random.nextInt(900000) + 100000;
    return value.toString();
  }

  void dispose() {
    _smsService.close();
  }
}
