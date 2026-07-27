import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const PolApp());
}

class PolApp extends StatelessWidget {
  const PolApp({super.key});

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
      home: const LoginPage(),
    );
  }
}
