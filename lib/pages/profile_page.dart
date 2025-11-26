// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:eramyadak_shop/services/auth_storage.dart';
import 'package:eramyadak_shop/widgets/account_webview.dart';
import 'package:eramyadak_shop/main.dart'; // برای RegistrationGate

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<AuthProfile?> _f;

  @override
  void initState() {
    super.initState();
    _f = AuthStorage.loadProfile();
  }

  void _refresh() => setState(() => _f = AuthStorage.loadProfile());

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پروفایل من'),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<AuthProfile?>(
          future: _f,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return Center(child: Text('خطا: ${s.error}'));
            }
            final p = s.data;
            if (p == null) {
              return Center(child: Text('اطلاعات ثبت‌نام یافت نشد.'));
            }

            final displayName = p.displayName.isEmpty ? 'کاربر' : p.displayName;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
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
                        child: Icon(Icons.person, size: 36),
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
                              'موبایل: ${p.phone}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountWebView(
                              title: 'ورود / حساب من',
                              path: '/my-account/',
                            ),
                          ),
                        ).then((_) => _refresh()),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('تنظیمات حساب (وب)'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountWebView(
                        title: 'تنظیمات حساب',
                        path: '/my-account/edit-account/',
                      ),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('خروج از اپ'),
                  subtitle: const Text(
                    'حذف ورود خودکار (دوباره OTP لازم می‌شود)',
                  ),
                  onTap: () async {
                    await AuthStorage.clearProfile();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const RegistrationGate(),
                      ),
                      (r) => false,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
