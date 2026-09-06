import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String threadId;
  const ChatPage({super.key, required this.threadId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<dynamic> _messages = [];
  final _msgController = TextEditingController();
  bool _isUploadingFile = false;
  bool _isInitialLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages(isFirstTime: true);

    // ⚡ آپدیت صامت و زنده هر ۲ ثانیه برای سین خوردن و دریافت پیام جدید (بدون ریلود و پرپک)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadMessages(isFirstTime: false);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool isFirstTime = false}) async {
    if (isFirstTime) {
      setState(() => _isInitialLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final list = await ApiService.fetchMessages(token, widget.threadId);

    if (mounted) {
      setState(() {
        _messages = list;
        if (isFirstTime) _isInitialLoading = false;
      });
    }
  }

  // 📎 انتخاب و ارسال فایل
  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? fileBytes = file.bytes;

        if (fileBytes == null && !kIsWeb && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          setState(() => _isUploadingFile = true);

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token') ?? '';

          final fileInfo = await ApiService.uploadChatFile(
            token: token,
            fileBytes: fileBytes,
            fileName: file.name,
          );

          if (fileInfo != null) {
            final ok = await ApiService.sendMessage(
              token,
              widget.threadId,
              _msgController.text.trim(),
              fileUrl: fileInfo['file_url'],
              fileType: fileInfo['file_type'],
              fileName: fileInfo['file_name'],
            );

            if (ok) {
              _msgController.clear();
              _loadMessages();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('خطا در آپلود فایل روی سرور.')),
              );
            }
          }
          setState(() => _isUploadingFile = false);
        }
      }
    } catch (e) {
      setState(() => _isUploadingFile = false);
      print("خطا در انتخاب فایل چت: $e");
    }
  }

  Future<void> _sendText() async {
    if (_msgController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final ok = await ApiService.sendMessage(token, widget.threadId, _msgController.text.trim());
    if (ok) {
      _msgController.clear();
      _loadMessages();
    }
  }

  // 📱 منوی اکشن کپی و حذف پیام
  void _showTelegramMessageMenu(dynamic m) {
    final isMe = m['is_me'] ?? false;
    final text = m['text'] ?? '';
    final messageId = m['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                if (text.toString().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: Color(0xFF1E6AFB)),
                    title: const Text('کپی متن پیام', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('متن پیام کپی شد.')),
                      );
                    },
                  ),
                if (isMe && messageId.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('حذف پیام', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('access_token') ?? '';
                      final ok = await ApiService.deleteChatMessage(token, messageId);
                      if (ok && mounted) {
                        _loadMessages();
                      }
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFileUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          title: const Text('گفتگو درباره پروژه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E6AFB)), onPressed: () => _loadMessages(isFirstTime: false))
          ],
        ),
        body: Column(
          children: [
            // لیست پیام‌ها با دوتیک سبز رنگ زنده
            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
                  : _messages.isEmpty
                  ? const Center(child: Text('هنوز هیچ پیامی ارسال نشده است.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : RefreshIndicator(
                onRefresh: () => _loadMessages(isFirstTime: false),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final isMe = m['is_me'] ?? false;
                    final isRead = (m['is_read'] == true) || (m['is_read'] == 1) || (m['is_read'].toString() == 'true');
                    final text = m['text'] ?? '';
                    final fileUrl = m['file_url'];
                    final fileType = m['file_type'];
                    final fileName = m['file_name'] ?? 'فایل پیوست';

                    return Align(
                      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _showTelegramMessageMenu(m),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.70,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF1E6AFB) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 2 : 16),
                              bottomRight: Radius.circular(isMe ? 16 : 2),
                            ),
                            border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: IntrinsicWidth(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fileUrl != null) ...[
                                  if (fileType == 'image') ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        fileUrl.startsWith('http') ? fileUrl : '${ApiService.baseUrl}$fileUrl',
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ] else ...[
                                    InkWell(
                                      onTap: () => _openFileUrl(fileUrl),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.white.withOpacity(0.2) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : const Color(0xFF1E6AFB), size: 20),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                fileName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFF1E293B)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.file_download, color: isMe ? Colors.white : const Color(0xFF10B981), size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ],

                                if (text.isNotEmpty)
                                  Text(
                                    text,
                                    style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 12, height: 1.4),
                                  ),

                                const SizedBox(height: 2),

                                // 🟢 تیک تک و دوتیک سبز رنگ سین خوردن (✓ / ✓✓)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      m['created_at'] ?? '',
                                      style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        isRead ? Icons.done_all : Icons.done, // ✓✓ دوتیک vs ✓ تک‌تیک
                                        size: 13,
                                        color: isRead ? const Color(0xFF6EE7B7) : Colors.white70, // رنگ دوتیک سبز سین‌شده
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // کادر پایین ارسال پیام و فایل
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploadingFile
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E6AFB)))
                        : const Icon(Icons.attach_file, color: Color(0xFF1E6AFB), size: 22),
                    onPressed: _isUploadingFile ? null : _pickAndSendFile,
                    tooltip: 'ارسال فایل یا عکس',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1E6AFB),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendText,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}