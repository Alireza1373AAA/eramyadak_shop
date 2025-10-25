// lib/pages/support_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> _open(Uri uri, BuildContext context) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('نمی‌توانم باز کنم: $uri')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبانی و ارتباط')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('تماس تلفنی'),
              subtitle: const Text('021-xxxxxxx'),
              onTap: () =>
                  _open(Uri(scheme: 'tel', path: '021xxxxxxx'), context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('واتس‌اپ'),
              subtitle: const Text('+98 9xx xxx xxxx'),
              onTap: () =>
                  _open(Uri.parse('https://wa.me/989xxxxxxxxx'), context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.send),
              title: const Text('تلگرام'),
              subtitle: const Text('@yourchannel'),
              onTap: () =>
                  _open(Uri.parse('https://t.me/yourchannel'), context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('وب‌سایت'),
              subtitle: const Text('eramyadak.com'),
              onTap: () => _open(Uri.parse('https://eramyadak.com'), context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('ایمیل'),
              subtitle: const Text('support@eramyadak.com'),
              onTap: () => _open(
                Uri(
                  scheme: 'mailto',
                  path: 'support@eramyadak.com',
                  query: 'subject=پشتیبانی اپ',
                ),
                context,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('آدرس روی نقشه'),
              subtitle: const Text('نمایش در Google Maps'),
              onTap: () => _open(
                Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=Eram+Yadak',
                ),
                context,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
