import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Refreshes unread notification and chat counts every few seconds while logged in.
class NotificationPoller extends ChangeNotifier {
  NotificationPoller._();

  static final NotificationPoller instance = NotificationPoller._();

  static const Duration interval = Duration(seconds: 3);

  Timer? _timer;
  bool _isFetching = false;
  bool _hasLoadedOnce = false;

  int unreadNotifications = 0;
  int unreadChats = 0;

  /// Notifications that arrived since the previous poll (0 when nothing new).
  int newArrivals = 0;

  void start() {
    if (_timer != null) return;
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _hasLoadedOnce = false;
    unreadNotifications = 0;
    unreadChats = 0;
    newArrivals = 0;
  }

  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;

      final counts = await ApiService.fetchNotificationCounts(token);
      final int notifs = counts['unread_notifications'] ?? 0;
      final int chats = counts['unread_chats'] ?? 0;

      newArrivals = _hasLoadedOnce && notifs > unreadNotifications ? notifs - unreadNotifications : 0;
      final changed = notifs != unreadNotifications || chats != unreadChats;
      _hasLoadedOnce = true;
      unreadNotifications = notifs;
      unreadChats = chats;

      if (changed) notifyListeners();
    } finally {
      _isFetching = false;
    }
  }
}
