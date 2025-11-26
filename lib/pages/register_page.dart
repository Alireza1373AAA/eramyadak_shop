// lib/pages/register_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:eramyadak_shop/config.dart';
import 'package:eramyadak_shop/services/otp_manager.dart';
import 'package:eramyadak_shop/services/sms_exception.dart';
import 'package:eramyadak_shop/services/auth_storage.dart';
import 'package:eramyadak_shop/data/woocommerce_api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.onRegistered,
    this.lockNavigation = false,
  });

  final VoidCallback? onRegistered;
  final bool lockNavigation;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();

  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  final _otpManager = OtpManager();
  final _wooApi = WooApi();

  bool _sending = false;
  bool _sent = false;
  bool _registering = false;
  bool _existingCustomer = false;
  bool _loginOnly = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final registered = await AuthStorage.isRegistered();
      if (!mounted) return;
      if (registered &&
          Navigator.of(context).canPop() &&
          !widget.lockNavigation) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Duration? get _remain => _otpManager.remaining;

  String _autoNameForPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final suf = cleaned.length >= 4
        ? cleaned.substring(cleaned.length - 4)
        : cleaned;
    return 'کاربر$suf';
  }

  // -----------------------------
  // ارسال کد پیامکی
  // -----------------------------
  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      final normalized = SmsConfig.normalizePhoneToPlus98(_phoneCtrl.text);

      // بررسی سریع وجود مشتری (اختیاری، اگر خطا داشتیم ادامه می‌دهیم)
      try {
        final exists = await _wooApi.customerExists(phone: normalized);
        if (mounted) setState(() => _existingCustomer = exists);
      } catch (e) {
        debugPrint('customerExists check failed: $e');
        // نادیده می‌گیریم؛ ارسال کد مهمتر است
      }

      await _otpManager.sendCode(_phoneCtrl.text);
      setState(() => _sent = true);

      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );

      if (!mounted) return;
      final msg = _existingCustomer
          ? 'کد تایید ارسال شد. (به نظر می‌رسد قبلاً ثبت‌نام کرده‌اید.)'
          : 'کد تایید ارسال شد.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on SmsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال پیامک: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطای غیرمنتظره: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // -----------------------------
  // ثبت‌نام / ورود
  // -----------------------------
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا «ارسال کد» را بزنید')),
      );
      return;
    }

    if (!_otpKey.currentState!.validate()) return;

    final err = _otpManager.validate(_phoneCtrl.text, _otpCtrl.text);
    if (err != null) {
      final msg = switch (err) {
        OtpValidationError.notRequested => 'ابتدا کد تایید را دریافت کنید.',
        OtpValidationError.phoneMismatch =>
          'شماره موبایل با شماره‌ای که کد برای آن ارسال شده متفاوت است.',
        OtpValidationError.expired =>
          'کد منقضی شده است. دوباره «ارسال کد» را بزنید.',
        OtpValidationError.codeMismatch => 'کد وارد شده صحیح نیست.',
        OtpValidationError.notAllowed =>
          'شماره شما مجاز به استفاده از این سرویس نیست.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    setState(() => _registering = true);

    try {
      final phonePlus98 = SmsConfig.normalizePhoneToPlus98(_phoneCtrl.text);
      final first = _loginOnly
          ? _autoNameForPhone(_phoneCtrl.text)
          : _firstCtrl.text.trim();
      final last = _loginOnly ? '' : _lastCtrl.text.trim();

      // 1) بررسی وجود مشتری با این شماره
      bool exists = false;
      try {
        exists = await _wooApi.customerExists(phone: phonePlus98);
      } catch (e) {
        debugPrint('customerExists failed: $e');
        // اگر چک نشد، ادامه می‌دهیم و سعی می‌کنیم createCustomer انجام شود.
      }

      // اگر حالت login-only فعال است و کاربر موجود نیست → خطا بده
      if (_loginOnly && !exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'این شماره قبلاً ثبت‌نام نکرده — ابتدا ثبت‌نام کنید.',
            ),
          ),
        );
        setState(() => _registering = false);
        return;
      }

      Map<String, dynamic>? customer;
      if (exists) {
        // کاربر قبلاً وجود دارد -> رفتار ورود (نیازی به createCustomer نیست)
        customer = null;
      } else {
        // تلاش برای ایجاد مشتری
        try {
          customer = await _wooApi.createCustomer(
            firstName: first.isEmpty
                ? _autoNameForPhone(_phoneCtrl.text)
                : first,
            lastName: last,
            phone: phonePlus98,
          );
          // createCustomer ممکن است null برگرداند اگر API پیام "existing email" فرستاد
          if (customer == null) {
            exists = true;
          }
        } on WooApiException catch (e) {
          // اگر خطایی غیر از "موجود بودن" دریافت شد، به کاربر اطلاع بده و بازگرد
          if (!mounted) rethrow;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در ثبت‌نام ووکامرس: ${e.message}')),
          );
          setState(() => _registering = false);
          return;
        }
      }

      // ذخیره پروفایل محلی برای ورود خودکار دفعات بعد
      final profile = AuthProfile(
        firstName: first,
        lastName: last,
        phone: phonePlus98,
      );
      await AuthStorage.saveProfile(profile);

      if (!mounted) return;

      final text = exists
          ? 'با این شماره قبلاً ثبت‌نام شده بود — ورود موفق.'
          : (customer == null
                ? 'ورود موفق.' // fallback
                : (_loginOnly
                      ? 'ورود با شماره موفق — اگر حساب جدید ساخته شد، نام از شماره تولید شد.'
                      : 'ثبت‌نام و ورود موفق.'));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

      widget.onRegistered?.call();

      if (!widget.lockNavigation && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در ذخیره اطلاعات: $e')));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final remain = _remain;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت‌نام / ورود با پیامک'),
          automaticallyImplyLeading: !widget.lockNavigation,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _loginOnly,
                        onChanged: (v) => setState(() => _loginOnly = v),
                        title: const Text(
                          'قبلاً ثبت‌نام کرده‌ام — فقط ورود با شماره',
                        ),
                        subtitle: const Text(
                          'اگر فعال باشد، فقط شماره لازم است.',
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _loginOnly
                            ? 'فقط شماره موبایل خود را وارد کنید. نام از شماره تولید و برای سرور ارسال می‌شود.'
                            : 'نام، نام‌خانوادگی و شماره موبایل خود را وارد کنید.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!_loginOnly) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'نام',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'نام را وارد کنید'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'نام خانوادگی',
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'نام خانوادگی را وارد کنید'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'شماره موبایل',
                                hintText: '0912xxxxxxx یا +98912xxxxxxx',
                                prefixIcon: Icon(Icons.phone_iphone),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'شماره موبایل الزامی است';
                                }
                                try {
                                  SmsConfig.normalizePhoneToPlus98(v);
                                  return null;
                                } catch (_) {
                                  return 'شماره موبایل معتبر نیست';
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sms_outlined),
                        label: Text(_sent ? 'ارسال مجدد کد' : 'ارسال کد'),
                      ),

                      if (_sent) ...[
                        const SizedBox(height: 12),
                        Form(
                          key: _otpKey,
                          child: TextFormField(
                            controller: _otpCtrl,
                            decoration: const InputDecoration(
                              labelText: 'کد تایید ۶ رقمی',
                              prefixIcon: Icon(Icons.verified),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (v == null || v.trim().length != 6)
                                ? 'کد ۶ رقمی را وارد کنید'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (remain != null)
                          Text(
                            remain == Duration.zero
                                ? 'کد منقضی شده — دوباره ارسال کنید.'
                                : 'زمان باقی‌مانده: '
                                      '${remain.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
                                      '${remain.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: remain == Duration.zero
                                  ? Colors.red
                                  : Colors.grey[700],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FilledButton(
                onPressed: _registering ? null : _register,
                child: _registering
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تکمیل ثبت‌نام / ورود'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
