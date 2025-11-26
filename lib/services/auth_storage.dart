// lib/services/auth_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProfile {
  final String firstName;
  final String lastName;
  final String phone;

  const AuthProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  /// اگر نام کاربر خالی باشد، شماره موبایل را به عنوان نام نمایش می‌دهد.
  String get displayName {
    final n = [
      firstName,
      lastName,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    if (n.isNotEmpty) return n;

    // نمایش شماره به صورت "کاربر: 0912..."
    if (phone.isNotEmpty) return "کاربر: $phone";

    return "کاربر";
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
  };

  factory AuthProfile.fromJson(Map<String, dynamic> j) => AuthProfile(
    firstName: (j['firstName'] ?? '').toString(),
    lastName: (j['lastName'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
  );

  /// نسخه‌ای برای بروزرسانی پروفایل بدون نیاز به بازنویسی کامل
  AuthProfile copyWith({String? firstName, String? lastName, String? phone}) {
    return AuthProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
    );
  }
}

class AuthStorage {
  static const _kProfile = 'auth_profile_v1';

  static Future<void> saveProfile(AuthProfile p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfile, jsonEncode(p.toJson()));
  }

  static Future<AuthProfile?> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return AuthProfile.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isRegistered() async => (await loadProfile()) != null;

  static Future<void> clearProfile() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kProfile);
  }

  /// بروزرسانی فقط بخشی از پروفایل
  static Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final old = await loadProfile();
    if (old == null) return;

    final updated = old.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    await saveProfile(updated);
  }
}
