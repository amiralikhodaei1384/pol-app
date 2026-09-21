import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'session_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PolApp());
}

/// Root widget that opens the login page or the dashboard based on the saved session.
class PolApp extends StatelessWidget {
  const PolApp({super.key});

  /// Reads the saved token and role from local storage.
  Future<Map<String, dynamic>> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isCompany = prefs.getBool('is_company') ?? false;
    final isAdmin = prefs.getBool('is_admin') ?? false;

    return {
      'isLoggedIn': token != null && token.isNotEmpty,
      'isCompany': isCompany,
      'isAdmin': isAdmin,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پل | Pol',
      debugShowCheckedModeBanner: false,
      navigatorKey: SessionGuard.navigatorKey,
      scaffoldMessengerKey: SessionGuard.messengerKey,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0072FF)),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data!['isLoggedIn'] == true) {
            if (snapshot.data!['isAdmin'] == true) return const AdminDashboardPage();
            return DashboardPage(isCompany: snapshot.data!['isCompany']);
          }

          return const LoginPage();
        },
      ),
    );
  }
}