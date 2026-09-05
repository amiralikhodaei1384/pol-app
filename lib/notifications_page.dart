import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:pol_app/employer_applications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
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
      _loadNotifications(); // رفرش لیست نوتیفیکیشن‌ها
    }
  }
  // 🔗 موتور کلیک و انتقال هوشمند به صفحه مربوطه (Deep Linking)
  void _handleNotificationTap(dynamic notif) {
    final type = notif['type'] ?? 'general';
    final linkId = notif['link_id']?.toString();

    if (type == 'chat' && linkId != null && linkId.isNotEmpty) {
      // ۱. انتقال مستقیم به صفحه همان چت
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(threadId: linkId),
        ),
      );
    } else if (type == 'application' && linkId != null && linkId.isNotEmpty) {
      // ۲. انتقال کارفرما به لیست رزومه‌های همان پروژه خاص
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployerApplicationsPage(
            projectId: linkId,
          ),
        ),
      );
    } else if (type == 'interview') {
      // ۳. انتقال دانشجو به داشبورد و مشاهده باکس مصاحبه حضوری
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardPage(isCompany: false),
        ),
            (route) => false,
      );
    } else {
      // پیام عمومی
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(notif['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
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