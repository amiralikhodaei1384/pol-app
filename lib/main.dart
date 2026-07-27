import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

void main() async {
  // اطمینان از مقداردهی اولیه فلاتر قبل از فراخوانی shared_preferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PolApp());
}

class PolApp extends StatelessWidget {
  const PolApp({super.key});

  // بررسی وضعیت ورود کاربر از حافظه دستگاه
  Future<Map<String, dynamic>> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isCompany = prefs.getBool('is_company') ?? false;

    return {
      'isLoggedIn': token != null && token.isNotEmpty,
      'isCompany': isCompany,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پل | Pol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Ravi',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0072FF),
          primary: const Color(0xFF0072FF),
          secondary: const Color(0xFF00C6FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _checkAuthStatus(),
        builder: (context, snapshot) {
          // در حال بررسی وضعیت ورود (نمایش صفحه لودینگ)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0072FF)),
              ),
            );
          }

          // اگر لاگین کرده بود -> هدایت به داشبورد مربوطه
          if (snapshot.hasData && snapshot.data!['isLoggedIn'] == true) {
            return DashboardPage(isCompany: snapshot.data!['isCompany']);
          }

          // در غیر این صورت -> صفحه ورود
          return const LoginPage();
        },
      ),
    );
  }
}