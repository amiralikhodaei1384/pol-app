import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lists the user's chat conversations.
class ChatThreadsPage extends StatefulWidget {
  const ChatThreadsPage({super.key});

  @override
  State<ChatThreadsPage> createState() => _ChatThreadsPageState();
}

class _ChatThreadsPageState extends State<ChatThreadsPage> {
  List<dynamic> _threads = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isAdmin = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _pollingTimer = Timer.periodic(NotificationPoller.interval, (_) => _loadThreads(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    _isAdmin = prefs.getBool('is_admin') ?? false;

    final list = await ApiService.fetchChatThreads(token);

    if (mounted) {
      setState(() {
        // A failed background refresh keeps the conversations already on screen.
        if (list != null) _threads = list;
        _loadFailed = list == null && (_threads.isEmpty || !silent);
        _isLoading = false;
      });
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
          title: const Text('پیام‌ها و گفتگوها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1E6AFB)),
              onPressed: _loadThreads,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : _loadFailed && _threads.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('دریافت گفتگوها ممکن نشد.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              TextButton.icon(onPressed: _loadThreads, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
            ],
          ),
        )
            : _threads.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _isAdmin
                  ? 'هنوز هیچ گفتگویی ندارید.\nبرای شروع، در «مدیریت کاربران» روی «گفتگو» یا «ارسال پیام» یک دانشجو یا شرکت بزنید.'
                  : 'هنوز هیچ گفتگویی ندارید.\nگفتگوها وقتی شروع می‌شوند که کارفرما یا مدیر سامانه برای شما پیام بفرستد.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.6),
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadThreads,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _threads.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final thread = _threads[index];
              final title = thread['title'] ?? 'گفتگو درباره پروژه';
              final party = thread['other_party'] ?? 'مخاطب';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.chat, color: Color(0xFF1E6AFB), size: 20),
                  ),
                  title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('طرف گفتگو: $party', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(threadId: thread['thread_id'].toString()),
                      ),
                    ).then((_) => _loadThreads());
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}