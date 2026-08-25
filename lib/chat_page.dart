import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String threadId;
  const ChatPage({super.key, required this.threadId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<dynamic> _messages = [];
  final _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final list = await ApiService.fetchMessages(token, widget.threadId);
    if (mounted) setState(() => _messages = list);
  }

  Future<void> _send() async {
    if (_msgController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final ok = await ApiService.sendMessage(token, widget.threadId, _msgController.text.trim());
    if (ok) {
      _msgController.clear();
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گفتگو درباره پروژه')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isMe = m['is_me'] ?? false;
                  return Align(
                    alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF1E6AFB) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: 'پیام خود را بنویسید...'))),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFF1E6AFB)), onPressed: _send),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}