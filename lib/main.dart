import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'pages/home_page.dart';
import 'pages/categories_page.dart';
import 'pages/cart_page.dart';
import 'pages/support_page.dart';
import 'pages/profile_page.dart';
import 'widgets/bottom_nav.dart';

void main() {
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
      home: const Shell(),
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
