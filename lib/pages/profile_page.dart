// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../services/auth_storage.dart';
import '../widgets/account_webview.dart'; // WebView عمومی حساب
import 'register_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<AuthProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthStorage.loadProfile();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = AuthStorage.loadProfile();
    });
  }

  void _open(
    BuildContext context, {
    required String title,
    required String path,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountWebView(title: title, path: path),
      ),
    ).then((_) => _refreshProfile());
  }

  Widget _buildHeader(BuildContext context, AuthProfile profile) {
    final displayName = profile.displayName;
    final phone = profile.phone.isNotEmpty ? profile.phone : 'شماره ثبت نشده';
    final email = profile.email.isNotEmpty ? profile.email : 'ایمیل ثبت نشده';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.amber,
            child: Icon(Icons.person, size: 36, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'موبایل: $phone',
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  'ایمیل: $email',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'مدیریت حساب در وب',
            onPressed: () => _open(
              context,
              title: 'ورود / حساب من',
              path: '/my-account/',
            ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پروفایل من'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'به‌روزرسانی اطلاعات',
              onPressed: _refreshProfile,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<AuthProfile?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('خطا در خواندن اطلاعات کاربر'),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Colors.amber),
                      const SizedBox(height: 12),
                      const Text(
                        'اطلاعات ثبت‌نام یافت نشد.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => RegisterPage(
                                    onRegistered: _refreshProfile,
                                  ),
                                ),
                              )
                              .then((_) => _refreshProfile());
                        },
                        child: const Text('ثبت‌نام مجدد'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildHeader(context, profile),
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('سفارش‌های من'),
                  subtitle: const Text('مشاهده وضعیت و تاریخچه سفارش‌ها'),
                  onTap: () => _open(
                    context,
                    title: 'سفارش‌های من',
                    path: '/my-account/orders/',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('علاقه‌مندی‌ها'),
                  subtitle: const Text('محصولاتی که نشان کرده‌اید'),
                  onTap: () =>
                      _open(context, title: 'علاقه‌مندی‌ها', path: '/wishlist/'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('آدرس‌های من'),
                  subtitle: const Text('مدیریت آدرس‌های ارسال'),
                  onTap: () => _open(
                    context,
                    title: 'آدرس‌های من',
                    path: '/my-account/edit-address/',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('تنظیمات حساب'),
                  subtitle: const Text('مدیریت مشخصات و رمز'),
                  onTap: () => _open(
                    context,
                    title: 'تنظیمات حساب',
                    path: '/my-account/edit-account/',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('راهنما و پشتیبانی'),
                  onTap: () => _open(context, title: 'پشتیبانی', path: '/contact/'),
                ),
                const Divider(),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _open(
                    context,
                    title: 'خروج',
                    path: '/my-account/customer-logout/',
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('خروج از حساب کاربری'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
