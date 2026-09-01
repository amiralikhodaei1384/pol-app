import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // باز کردن رزومه PDF دانشجو در مرورگر/نمایشگر
  void _openResumePdf(String? resumePath) async {
    if (resumePath == null || resumePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل رزومه‌ای توسط این دانشجو آپلود نشده است.')),
      );
      return;
    }
    final fullUrl = resumePath.startsWith('http') ? resumePath : '${ApiService.baseUrl}$resumePath';
    final uri = Uri.parse(fullUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('امکان بازکردن لینک رزومه وجود ندارد: $fullUrl')),
      );
    }
  }

  // مشاهده کامل مشخصات و سوابق تحصیلی/کاری دانشجو
  void _showStudentDetailsModal(dynamic app) {
    final educations = (app['student_educations'] as List<dynamic>?) ?? [];
    final workExp = (app['student_work_experiences'] as List<dynamic>?) ?? [];
    final skills = (app['student_skills'] as List<dynamic>?)?.cast<String>() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(app['student_name'] ?? 'دانشجو', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  Text('شماره تماس: ${app['student_phone'] ?? "ثبت نشده"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Divider(height: 24),

                  // سوابق تحصیلی
                  const Text('🎓 سوابق تحصیلی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E6AFB))),
                  const SizedBox(height: 8),
                  if (educations.isEmpty)
                    const Text('سابقه تحصیلی ثبت نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey))
                  else
                    ...educations.map((edu) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Text('${edu['degree']} ${edu['major']} - ${edu['university']} (${edu['start_year']} تا ${edu['end_year']}) - معدل: ${edu['gpa']}', style: const TextStyle(fontSize: 11)),
                    )),

                  const SizedBox(height: 16),

                  // سوابق کاری
                  const Text('💼 سوابق شغلی و کاری:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                  const SizedBox(height: 8),
                  if (workExp.isEmpty)
                    const Text('سابقه کاری ثبت نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey))
                  else
                    ...workExp.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Text('${w['position']} در ${w['company']} (${w['from_year']} تا ${w['to_year']})', style: const TextStyle(fontSize: 11)),
                    )),

                  const SizedBox(height: 16),

                  // مهارت‌ها
                  const Text('🛠️ مهارت‌های تخصصی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 10)))).toList(),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openResumePdf(app['student_resume']),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('دانلود / مشاهده فایل PDF رزومه'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // دیالوگ انتخاب تاریخ شمسی (Jalali Date Picker) جهت دعوت به مصاحبه حضوری
  void _showScheduleModal(String appId) {
    String selectedYear = '1405';
    String selectedMonth = '04';
    String selectedDay = '15';
    String selectedTime = '10:30';

    final addressCtrl = TextEditingController(text: 'تهران، خیابان آزادی، پلاک ۱۲');
    final noteCtrl = TextEditingController();

    final List<String> years = ['1405', '1406'];
    final List<String> months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
    final List<String> days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    final List<String> times = ['09:00', '10:00', '10:30', '11:00', '14:00', '15:30', '16:00'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.event_available, color: Color(0xFF1E6AFB)),
                  SizedBox(width: 8),
                  Text('دعوت به مصاحبه حضوری', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('انتخاب تاریخ شمسی مصاحبه:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),

                    // انتخابگر روز/ماه/سال شمسی
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedYear,
                            decoration: const InputDecoration(labelText: 'سال', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (v) => setModalState(() => selectedYear = v!),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedMonth,
                            decoration: const InputDecoration(labelText: 'ماه', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            items: months.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (v) => setModalState(() => selectedMonth = v!),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDay,
                            decoration: const InputDecoration(labelText: 'روز', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            items: days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (v) => setModalState(() => selectedDay = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // انتخاب ساعت
                    DropdownButtonFormField<String>(
                      value: selectedTime,
                      decoration: const InputDecoration(labelText: 'ساعت مصاحبه'),
                      items: times.map((t) => DropdownMenuItem(value: t, child: Text('ساعت $t'))).toList(),
                      onChanged: (v) => setModalState(() => selectedTime = v!),
                    ),
                    const SizedBox(height: 12),

                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'آدرس محل مراجعه حضوری')),
                    const SizedBox(height: 12),
                    TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'توضیحات همراه (اختیاری)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final fullShamsiDate = '$selectedYear/$selectedMonth/$selectedDay - ساعت $selectedTime';
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('access_token') ?? '';

                    final ok = await ApiService.scheduleInterview(token, appId, fullShamsiDate, addressCtrl.text, noteCtrl.text);
                    if (ok && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('دعوت به مصاحبه حضوری با تاریخ شمسی برای دانشجو ارسال شد.'), backgroundColor: Color(0xFF10B981)),
                      );
                      _loadApplications();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  child: const Text('ارسال دعوت‌نامه'),
                ),
              ],
            ),
          );
        },
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('مدیریت درخواست‌ها و رزومه‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _applications.length,
          itemBuilder: (context, index) {
            final app = _applications[index];
            final statusRaw = app['status'] ?? 'applied';
            final isShortlisted = statusRaw == 'shortlisted';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(app['student_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                          child: Text('${app['match_score']}٪ تطابق', style: const TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${app['student_university']} • ${app['student_major']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 12),

                    // دکمه‌های اکشن بررسی رزومه و اقدامات
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // ۱. دکمه مشاهده رزومه PDF
                        ElevatedButton.icon(
                          onPressed: () => _openResumePdf(app['student_resume']),
                          icon: const Icon(Icons.picture_as_pdf, size: 14),
                          label: const Text('مشاهده رزومه PDF', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6AFB), foregroundColor: Colors.white),
                        ),

                        // ۲. دکمه مشاهده کامل مشخصات
                        OutlinedButton.icon(
                          onPressed: () => _showStudentDetailsModal(app),
                          icon: const Icon(Icons.person_search, size: 14),
                          label: const Text('مشاهده سوابق دانشجو', style: TextStyle(fontSize: 10)),
                        ),

                        // ۳. دکمه دعوت به مصاحبه حضوری
                        ElevatedButton.icon(
                          onPressed: () => _showScheduleModal(app['application_id']),
                          icon: const Icon(Icons.event_available, size: 14),
                          label: Text(isShortlisted ? 'ویرایش مصاحبه' : 'دعوت به مصاحبه حضوری', style: const TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        ),

                        // ۴. دکمه شروع چت
                        OutlinedButton.icon(
                          onPressed: () => _openChat(app['application_id']),
                          icon: const Icon(Icons.chat, size: 14),
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