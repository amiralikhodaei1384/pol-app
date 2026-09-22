import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:pol_app/employer_applications_page.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lists the user's notifications.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _pollingTimer = Timer.periodic(NotificationPoller.interval, (_) => _loadNotifications(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final list = await ApiService.fetchNotifications(token);

    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }
  Future<void> _deleteNotif(String notifId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final ok = await ApiService.deleteNotification(token, notifId);
    if (ok) {
      _loadNotifications();
    }
  }
  /// Opens the screen related to the tapped notification.
  void _handleNotificationTap(dynamic notif) {
    final type = notif['type'] ?? 'general';
    final linkId = notif['link_id']?.toString();

    if (type == 'chat' && linkId != null && linkId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(threadId: linkId),
        ),
      );
    } else if (type == 'application' && linkId != null && linkId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployerApplicationsPage(
            projectId: linkId,
          ),
        ),
      );
    } else if (type == 'interview' || type == 'decision') {
      // link_id is the project: open the dashboard scrolled to that application.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(isCompany: false, focusProjectId: linkId),
        ),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notif['message'] ?? '')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          title: const Text('اعلان‌ها و نوتیفیکیشن‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1E6AFB)),
              onPressed: _loadNotifications,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : _notifications.isEmpty
            ? const Center(
          child: Text('هیچ اعلانی یافت نشد.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        )
            : RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notif = _notifications[index];
              final type = notif['type'] ?? 'general';

              IconData iconData = Icons.notifications;
              Color iconBg = const Color(0xFFE3F2FD);
              Color iconColor = const Color(0xFF1E6AFB);
              String actionText = 'مشاهده جزییات ◄';

              if (type == 'interview') {
                iconData = Icons.event_available;
                iconBg = const Color(0xFFECFDF5);
                iconColor = const Color(0xFF10B981);
                actionText = 'مشاهده زمان و آدرس مصاحبه ◄';
              } else if (type == 'chat') {
                iconData = Icons.chat_bubble_outline;
                iconBg = const Color(0xFFFFF3E0);
                iconColor = Colors.orange;
                actionText = 'ورود به چت و پاسخ ◄';
              } else if (type == 'application') {
                iconData = Icons.person_add_alt_1_outlined;
                iconBg = const Color(0xFFF3E5F5);
                iconColor = Colors.purple;
                actionText = 'بررسی رزومه متقاضی ◄';
              } else if (type == 'decision') {
                final accepted = (notif['title'] ?? '').toString().contains('پذیرفته شد');
                iconData = accepted ? Icons.celebration_rounded : Icons.fact_check_outlined;
                iconBg = accepted ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9);
                iconColor = accepted ? const Color(0xFF10B981) : const Color(0xFF64748B);
                actionText = 'مشاهده نتیجه درخواست ◄';
              } else if (type == 'admin') {
                iconData = Icons.campaign_outlined;
                iconBg = const Color(0xFFFEF3C7);
                iconColor = const Color(0xFFB45309);
                actionText = 'پیام مدیر سامانه';
              }

              return InkWell(
                onTap: () => _handleNotificationTap(notif),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: iconBg,
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Long titles (e.g. the acceptance one) wrap instead of pushing the date off-screen.
                                Expanded(
                                  child: Text(notif['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Text(notif['created_at'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteNotif(notif['id'].toString()),
                                      tooltip: 'حذف اعلان',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif['message'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                actionText,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}