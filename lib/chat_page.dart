import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final list = await ApiService.fetchMessages(token, widget.threadId);
    if (mounted) {
      setState(() {
        _messages = list;
        _isLoading = false;
      });
    }
  }

  // 📎 انتخاب و ارسال فایل (پشتیبانی هوشمند از وب، ویندوز و اندروید)
  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? fileBytes = file.bytes;

        // خوانش بایت‌ها از آدرس فایل در سیستم‌عامل‌های ویندوز/اندروید
        if (fileBytes == null && !kIsWeb && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          setState(() => _isUploadingFile = true);

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token') ?? '';

          // ۱. آپلود فایل روی سرور
          final fileInfo = await ApiService.uploadChatFile(
            token: token,
            fileBytes: fileBytes,
            fileName: file.name,
          );

          if (fileInfo != null) {
            // ۲. ثبت پیام چت همراه با لینک فایل
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

  // ارسال متن پیام
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

  // 🗑️ حذف پیام با لمس طولانی (Long Press)
  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف پیام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: const Text('آیا از حذف این پیام اطمینان دارید؟', style: TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('access_token') ?? '';
                final ok = await ApiService.deleteChatMessage(token, messageId);
                if (ok && mounted) {
                  Navigator.pop(context);
                  _loadMessages(); // رفرش لیست پیام‌ها
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('حذف پیام'),
            ),
          ],
        ),
      ),
    );
  }

  // دانلود / باز کردن فایل پیوست
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
            IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E6AFB)), onPressed: _loadMessages)
          ],
        ),
        body: Column(
          children: [
            // لیست پیام‌ها با حباب‌های فشرده و تلگرامی
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
                  : _messages.isEmpty
                  ? const Center(child: Text('هنوز هیچ پیامی ارسال نشده است.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isMe = m['is_me'] ?? false;
                  final text = m['text'] ?? '';
                  final fileUrl = m['file_url'];
                  final fileType = m['file_type'];
                  final fileName = m['file_name'] ?? 'فایل پیوست';
                  final messageId = m['id']?.toString() ?? '';

                  return Align(
                    alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: InkWell(
                      onLongPress: isMe && messageId.isNotEmpty
                          ? () => _confirmDeleteMessage(messageId)
                          : null, // حذف با لمس طولانی روی پیام خود
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.70, // حداکثر ۷۰٪ عرض
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

                        // 📱 کادر اندازه دقیق متن پیام (تلگرامی)
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🖼️ اگر پیام حاوی عکس یا فایل باشد
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
                                  // 📄 فایل غیر تصویری (PDF, ZIP, DOC...)
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

                              // متن پیام
                              if (text.isNotEmpty)
                                Text(
                                  text,
                                  style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 12, height: 1.4),
                                ),

                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Spacer(),
                                  Text(
                                    m['created_at'] ?? '',
                                    style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey),
                                  ),
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

            // کادر پایین: آیکون پیوست فایل 📎 + کادر تایپ + دکمه ارسال
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