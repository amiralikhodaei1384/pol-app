import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployerApplicationsPage extends StatefulWidget {
  const EmployerApplicationsPage({super.key});

  @override
  State<EmployerApplicationsPage> createState() => _EmployerApplicationsPageState();
}

class _EmployerApplicationsPageState extends State<EmployerApplicationsPage> {
  List<dynamic> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final list = await ApiService.fetchCompanyApplications(token);
    if (mounted) setState(() { _applications = list; _isLoading = false; });
  }

  void _showScheduleModal(String appId) {
    final dateCtrl = TextEditingController(text: '1405/04/10 - ساعت 10:00');
    final addressCtrl = TextEditingController(text: 'تهران، خیابان آزادی، پلاک ۱۲');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دعوت به مصاحبه حضوری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'تاریخ و ساعت جلسه')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'آدرس دفتر برای مراجعه')),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'توضیحات اضافی')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('access_token') ?? '';
                final ok = await ApiService.scheduleInterview(token, appId, dateCtrl.text, addressCtrl.text, noteCtrl.text);
                if (ok && mounted) {
                  Navigator.pop(context);
                  _loadApplications();
                }
              },
              child: const Text('ثبت دعوت‌نامه'),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final threadId = await ApiService.startChat(token, appId);
    if (threadId != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(threadId: threadId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مدیریت درخواست‌ها و متقاضیان')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _applications.length,
          itemBuilder: (context, index) {
            final app = _applications[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(app['student_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                          child: Text('${app['match_score']}٪ تطابق', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${app['student_university']} • ${app['student_major']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showScheduleModal(app['application_id']),
                          icon: const Icon(Icons.event, size: 16),
                          label: const Text('دعوت به مصاحبه حضوری', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openChat(app['application_id']),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('شروع چت', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}