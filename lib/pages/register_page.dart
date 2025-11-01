import 'dart:async';

import 'package:flutter/material.dart';

import '../data/woocommerce_api.dart';
import '../services/auth_storage.dart';
import '../services/otp_manager.dart';
import '../services/sms_exception.dart';
import '../services/sms_service.dart';
import '../widgets/account_webview.dart';

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

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  final _otpManager = OtpManager();
  final WooApi _wooApi = WooApi();

  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _isRegistering = false;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpManager.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final remaining = _otpManager.remaining;

    return WillPopScope(
      onWillPop: () async => !widget.lockNavigation,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ثبت‌نام با تایید پیامکی'),
            centerTitle: true,
            automaticallyImplyLeading: !widget.lockNavigation,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'برای ساخت حساب کاربری ابتدا اطلاعات خود را وارد کنید. سپس کد تایید برای شماره موبایل‌تان ارسال خواهد شد.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildFirstNameField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildLastNameField()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildEmailField(),
                              const SizedBox(height: 12),
                              _buildPhoneField(),
                              const SizedBox(height: 12),
                              _buildPasswordField(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isSendingCode ? null : _onSendCode,
                          icon: _isSendingCode
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: Text(
                            _codeSent ? 'ارسال مجدد کد تایید' : 'ارسال کد تایید',
                          ),
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: 12),
                          Form(
                            key: _otpKey,
                            child: _buildOtpField(),
                          ),
                          const SizedBox(height: 8),
                          if (remaining != null)
                            Text(
                              remaining == Duration.zero
                                  ? 'کد منقضی شده است. دوباره ارسال کنید.'
                                  : 'مدت اعتبار کد: ${_formatRemaining(remaining)}',
                              style: TextStyle(
                                color: remaining == Duration.zero
                                    ? Colors.red
                                    : Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isRegistering ? null : _onRegister,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isRegistering
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ایجاد حساب کاربری'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameCtrl,
      decoration: const InputDecoration(
        labelText: 'نام',
        prefixIcon: Icon(Icons.person_outline),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'لطفاً نام خود را وارد کنید';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameCtrl,
      decoration: const InputDecoration(
        labelText: 'نام خانوادگی',
        prefixIcon: Icon(Icons.person),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'لطفاً نام خانوادگی را وارد کنید';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      decoration: const InputDecoration(
        labelText: 'ایمیل',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'ایمیل الزامی است';
        }
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'ایمیل معتبر وارد کنید';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      decoration: const InputDecoration(
        labelText: 'شماره موبایل',
        prefixIcon: Icon(Icons.phone_iphone),
      ),
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'شماره موبایل الزامی است';
        }
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10) {
          return 'شماره موبایل معتبر نیست';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      decoration: const InputDecoration(
        labelText: 'رمز عبور',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      obscureText: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'رمز عبور را وارد کنید';
        }
        if (value.length < 6) {
          return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
        }
        return null;
      },
    );
  }

  Widget _buildOtpField() {
    return TextFormField(
      controller: _otpCtrl,
      decoration: const InputDecoration(
        labelText: 'کد تایید',
        prefixIcon: Icon(Icons.verified_outlined),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().length != 6) {
          return 'کد تایید شش رقمی را وارد کنید';
        }
        return null;
      },
    );
  }

  Future<void> _onSendCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingCode = true;
    });

    try {
      final messageId = await _otpManager.sendCode(_phoneCtrl.text);
      setState(() {
        _codeSent = true;
      });
      _startCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('کد تایید ارسال شد. (شناسه پیام: $messageId)')),
      );
    } on SmsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال پیامک: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای غیرمنتظره در ارسال پیامک: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_codeSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا کد تایید را دریافت کنید.')),
      );
      return;
    }

    if (!_otpKey.currentState!.validate()) {
      return;
    }

    OtpValidationError? otpError;
    try {
      otpError = _otpManager.validate(_phoneCtrl.text, _otpCtrl.text);
    } on SmsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('شماره موبایل معتبر نیست: ${e.message}')),
      );
      return;
    }

    if (otpError != null) {
      final message = _mapOtpError(otpError);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final customer = await _wooApi.createCustomer(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _otpManager.lastPhone ?? _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!await _saveRegistrationLocally()) {
        return;
      }

      if (!mounted) return;
      final shouldOpenAccount = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('ثبت‌نام موفق'),
            content: Text('کاربر ${customer['email']} با موفقیت ایجاد شد.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('ورود به حساب'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('بستن'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      _handlePostRegistrationNavigation(shouldOpenAccount ?? false);
    } on WooApiException catch (e) {
      if (_isAlreadyRegisteredError(e)) {
        if (!await _saveRegistrationLocally()) {
          return;
        }

        if (!mounted) return;

        final openAccount = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('حساب کاربری موجود است'),
              content: const Text(
                'این ایمیل یا شماره قبلاً در سیستم ثبت شده بود. می‌توانید وارد حساب خود شوید.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('ورود به حساب'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('ادامه'),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        _handlePostRegistrationNavigation(openAccount ?? false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ایجاد کاربر: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطای غیرمنتظره در ایجاد کاربر: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<bool> _saveRegistrationLocally() async {
    try {
      await AuthStorage.markRegistered(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _otpManager.lastPhone ?? _phoneCtrl.text.trim(),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ذخیره اطلاعات ثبت‌نام: $error')),
      );
      return false;
    }
  }

  void _handlePostRegistrationNavigation(bool openAccount) {
    if (!mounted) return;
    if (openAccount) {
      final route = MaterialPageRoute(
        builder: (_) => const AccountWebView(
          title: 'ورود / حساب من',
          path: '/my-account/',
        ),
      );
      if (widget.lockNavigation) {
        Navigator.of(context).push(route);
      } else {
        Navigator.of(context).pushReplacement(route);
      }
    } else if (!widget.lockNavigation && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onRegistered?.call();
  }

  bool _isAlreadyRegisteredError(WooApiException error) {
    final message = error.message.toLowerCase();
    return (error.statusCode == 400 || error.statusCode == 409) &&
        (message.contains('already registered') ||
            message.contains('already exists'));
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _otpManager.remaining;
      if (remaining == null || remaining == Duration.zero) {
        setState(() {});
        _countdownTimer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _mapOtpError(OtpValidationError error) {
    switch (error) {
      case OtpValidationError.notRequested:
        return 'کد تاییدی ارسال نشده است. روی «ارسال کد» بزنید.';
      case OtpValidationError.phoneMismatch:
        return 'شماره موبایل با شماره‌ای که کد برای آن ارسال شده متفاوت است.';
      case OtpValidationError.expired:
        return 'کد تایید منقضی شده است. دوباره درخواست بدهید.';
      case OtpValidationError.codeMismatch:
        return 'کد واردشده صحیح نیست.';
    }
  }
}
