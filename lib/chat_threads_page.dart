import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatThreadsPage extends StatefulWidget {
  const ChatThreadsPage({super.key});

  @override
  State<ChatThreadsPage> createState() => _ChatThreadsPageState();
}

class _ChatThreadsPageState extends State<ChatThreadsPage> {
  List<dynamic> _threads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final list = await ApiService.fetchChatThreads(token);

    if (mounted) {
      setState(() {
        _threads = list;
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
            : _threads.isEmpty
            ? const Center(
          child: Text('هنوز هیچ گفتگویی فعال نشده است.\n(چت‌ها پس از اقدام کارفرما فعال می‌شوند)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5)),
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