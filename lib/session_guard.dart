import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pol_app/login_page.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signs the user out from anywhere in the app when the server says their account was blocked.
class SessionGuard {
  SessionGuard._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static bool _loggingOut = false;

  static Future<void> forceLogout() async {
    // Several requests can fail at once (poller + page load); log out only once.
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      NotificationPoller.instance.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('حساب کاربری شما توسط مدیر مسدود شده است و از حساب خارج شدید.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      _loggingOut = false;
    }
  }
}

/// HTTP client that watches every authenticated response for the server's "account blocked" signal.
class SessionGuardClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    // Login itself has no token; its 403 is shown on the login page instead.
    if (response.statusCode == 403 &&
        response.headers['x-account-blocked'] == '1' &&
        request.headers.containsKey('Authorization')) {
      SessionGuard.forceLogout();
    }
    return response;
  }
}
