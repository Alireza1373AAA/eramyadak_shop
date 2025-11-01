import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'pages/home_page.dart';
import 'pages/categories_page.dart';
import 'pages/cart_page.dart';
import 'pages/support_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart';
import 'services/auth_storage.dart';
import 'widgets/bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eram Yadak',
      debugShowCheckedModeBanner: false,

      // 🎨 تم اپلیکیشن
      theme: AppTheme.theme(),

      // 🌍 پشتیبانی از زبان فارسی و راست‌چین سراسری
      locale: const Locale('fa'),
      supportedLocales: const [
        Locale('fa', ''), // فارسی
        Locale('en', ''), // انگلیسی (اختیاری)
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 🏠 صفحه اصلی
      home: const RegistrationGate(),
    );
  }
}

class RegistrationGate extends StatefulWidget {
  const RegistrationGate({super.key});

  @override
  State<RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<RegistrationGate> {
  late Future<bool> _registrationFuture;

  @override
  void initState() {
    super.initState();
    _registrationFuture = AuthStorage.isRegistered();
  }

  void _handleRegistered() {
    setState(() {
      _registrationFuture = Future<bool>.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _registrationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'خطا در بررسی وضعیت ثبت‌نام',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _registrationFuture = AuthStorage.isRegistered();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isRegistered = snapshot.data ?? false;
        if (!isRegistered) {
          return RegisterPage(
            lockNavigation: true,
            onRegistered: _handleRegistered,
          );
        }

        return const Shell();
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 1;

  @override
  Widget build(BuildContext context) {
    // 📱 صفحات اپ
    final pages = <int, Widget>{
      0: const CategoriesPage(),
      1: const HomePage(),
      2: const CartPage(),
      3: const SupportPage(),
      4: const ProfilePage(),
    };

    return Scaffold(
      body: pages[idx]!,
      bottomNavigationBar: YellowBottomNav(
        index: idx,
        onTap: (i) => setState(() => idx = i),
      ),
    );
  }
}
