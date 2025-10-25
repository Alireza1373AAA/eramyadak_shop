// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../widgets/account_webview.dart'; // WebView عمومی حساب

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('پروفایل من'), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // کارت ورود/داشبورد
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.amber, // ← اصلاح شد
                    child: Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'کاربر مهمان',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'وارد حساب خود شوید',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'ورود یا ثبت‌نام',
                    onPressed: () => _open(
                      context,
                      title: 'ورود / حساب من',
                      path: '/my-account/',
                    ),
                    icon: const Icon(Icons.login),
                  ),
                ],
              ),
            ),

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

            // خروج
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
        ),
      ),
    );
  }
}
