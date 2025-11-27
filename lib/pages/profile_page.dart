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

  Future<void> _editAddress(AuthProfile profile) async {
    final cityCtrl = TextEditingController(text: profile.city);
    final addressCtrl = TextEditingController(text: profile.address);
    final postalCodeCtrl = TextEditingController(text: profile.postalCode);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ویرایش آدرس',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شهر',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'آدرس کامل',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postalCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'کد پستی',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.markunread_mailbox),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ذخیره'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      await AuthStorage.updateProfile(
        city: cityCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        postalCode: postalCodeCtrl.text.trim(),
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('آدرس با موفقیت ذخیره شد')),
        );
      }
    }

    cityCtrl.dispose();
    addressCtrl.dispose();
    postalCodeCtrl.dispose();
  }

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
                const SizedBox(height: 16),
                // بخش آدرس
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF1A237E)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'آدرس',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _editAddress(p),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('ویرایش'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1A237E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (p.fullAddress.isNotEmpty)
                        Text(
                          p.fullAddress,
                          style: const TextStyle(fontSize: 14),
                        )
                      else
                        const Text(
                          'آدرسی ثبت نشده است. روی ویرایش کلیک کنید.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      if (p.postalCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'کد پستی: ${p.postalCode}',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
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
