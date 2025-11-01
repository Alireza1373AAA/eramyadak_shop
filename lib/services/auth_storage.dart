import 'package:shared_preferences/shared_preferences.dart';

/// اطلاعات پایهٔ کاربر که پس از ثبت‌نام ذخیره می‌شود.
class AuthProfile {
  const AuthProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  String get displayName {
    final parts = [firstName, lastName]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'کاربر فروشگاه';
    }
    return parts.join(' ');
  }
}

/// مدیریت ذخیره‌سازی وضعیت ثبت‌نام کاربر در حافظهٔ محلی.
class AuthStorage {
  static const _registeredKey = 'auth.registered';
  static const _firstNameKey = 'auth.firstName';
  static const _lastNameKey = 'auth.lastName';
  static const _emailKey = 'auth.email';
  static const _phoneKey = 'auth.phone';

  /// بررسی اینکه آیا کاربر قبلاً ثبت‌نام کرده است یا خیر.
  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_registeredKey) ?? false;
  }

  /// ذخیرهٔ اطلاعات کاربر پس از ثبت‌نام موفق.
  static Future<void> markRegistered({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_registeredKey, true);
    await prefs.setString(_firstNameKey, firstName.trim());
    await prefs.setString(_lastNameKey, lastName.trim());
    await prefs.setString(_emailKey, email.trim());
    await prefs.setString(_phoneKey, phone.trim());
  }

  /// بارگذاری اطلاعات کاربر ثبت‌نام‌شده.
  static Future<AuthProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_registeredKey) ?? false)) {
      return null;
    }

    return AuthProfile(
      firstName: prefs.getString(_firstNameKey) ?? '',
      lastName: prefs.getString(_lastNameKey) ?? '',
      email: prefs.getString(_emailKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
    );
  }

  /// پاک کردن اطلاعات ذخیره‌شده (مثلاً هنگام خروج کامل).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registeredKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
  }
}
