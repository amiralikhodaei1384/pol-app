import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmployerApplicationsPage extends StatefulWidget {
  final String? projectId;    // اگر متقاضیان یک پروژه خاص مد نظر باشد
  final String? projectTitle; // عنوان پروژه جهت نمایش در هدر

  const EmployerApplicationsPage({
    super.key,
    this.projectId,
    this.projectTitle,
  });

  @override
  State<EmployerApplicationsPage> createState() => _EmployerApplicationsPageState();
}

class _EmployerApplicationsPageState extends State<EmployerApplicationsPage> {
  List<dynamic> _applications = [];
  bool _isLoading = true;
  String _companyAddress = ''; // آدرس ثبت‌شده واقعی شرکت در پروفایل

  // ذخیره شناسه کارت‌های بازشده (Expand شده)
  final Set<String> _expandedAppIds = {};

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // ۱. بارگذاری آدرس واقعی ثبت‌شده شرکت از پروفایل
    if (token.isNotEmpty) {
      final userData = await ApiService.getMe(token);
      if (userData != null && userData['company'] != null) {
        _companyAddress = userData['company']['address'] ?? '';
      }
    }

    // ۲. بارگذاری متقاضیان
    final list = await ApiService.fetchCompanyApplications(token, projectId: widget.projectId);
    if (mounted) setState(() { _applications = list; _isLoading = false; });
  }

  // باز کردن رزومه PDF دانشجو در مرورگر
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

  // 🏛️ مدال دعوت به مصاحبه حضوری (با فیلد متنی معمولی برای ساعت دلخواه)
  void _showScheduleModal(String appId) {
    String selectedYear = '1405';
    String selectedMonth = '04';
    String selectedDay = '15';

    // فیلد متنی معمولی برای وارد کردن هر ساعت دلخواه
    final timeCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: _companyAddress);
    final noteCtrl = TextEditingController();

    final List<String> years = ['1405', '1406'];
    final List<String> months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
    final List<String> days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
              child: Container(
                width: isMobile ? double.infinity : 550,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_available, color: Color(0xFF1E6AFB), size: 24),
                              SizedBox(width: 8),
                              Text('تنظیم زمان و مکان مصاحبه حضوری', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      const Text('تاریخ شمسی مصاحبه:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 8),

                      // انتخابگر سال / ماه / روز
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedYear,
                              decoration: _inputDec('سال'),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setModalState(() => selectedYear = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedMonth,
                              decoration: _inputDec('ماه'),
                              items: months.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setModalState(() => selectedMonth = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedDay,
                              decoration: _inputDec('روز'),
                              items: days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setModalState(() => selectedDay = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ⏱️ فیلد متنی معمولی برای ساعت دلخواه
                      const Text('ساعت مصاحبه *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: timeCtrl,
                        keyboardType: TextInputType.datetime,
                        decoration: _inputDec('فقط عدد ساعت را وارد کنید، مثلاً 11 یا 10:30 (نه «ساعت یازده»)').copyWith(
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.45)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('آدرس دقیق محل مراجعه حضوری *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: addressCtrl,
                        decoration: _inputDec('آدرس دفتر شرکت...'),
                      ),
                      const SizedBox(height: 16),

                      const Text('توضیحات و مدارک همراه (اختیاری)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: _inputDec('توضیحات لازم برای دانشجو...'),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final timeText = timeCtrl.text.trim();
                              final addressText = addressCtrl.text.trim();

                              if (timeText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('لطفاً ساعت مصاحبه را وارد کنید.')),
                                );
                                return;
                              }

                              if (addressText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('لطفاً آدرس محل مراجعه را وارد کنید.')),
                                );
                                return;
                              }

                              final fullShamsiDate = '$selectedYear/$selectedMonth/$selectedDay - ساعت $timeText';
                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('access_token') ?? '';

                              final ok = await ApiService.scheduleInterview(token, appId, fullShamsiDate, addressText, noteCtrl.text.trim());
                              if (ok && mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('دعوت‌نامه مصاحبه حضوری برای دانشجو ارسال شد.'), backgroundColor: Color(0xFF10B981)),
                                );
                                _loadApplications();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('ثبت و ارسال دعوت‌نامه', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // 🔽 ساخت کارت متقاضی با قابلیت بازشدن با کلیک روی هرجای کارت
  Widget _buildApplicantCard(dynamic app) {
    final appId = app['application_id'].toString();
    final isExpanded = _expandedAppIds.contains(appId);
    final isShortlisted = app['status'] == 'shortlisted';
    final studentMsg = app['student_message']?.toString().trim();
    final educations = (app['student_educations'] as List<dynamic>?) ?? [];
    final workExp = (app['student_work_experiences'] as List<dynamic>?) ?? [];
    final skills = (app['student_skills'] as List<dynamic>?)?.cast<String>() ?? [];

    void toggleExpand() {
      setState(() {
        if (isExpanded) {
          _expandedAppIds.remove(appId);
        } else {
          _expandedAppIds.add(appId);
        }
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFF1E6AFB) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👈 کلیک روی کل بخش بالای کارت
          InkWell(
            onTap: toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(app['student_name'] ?? 'دانشجو', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                        child: Text('${app['match_score']}٪ تطابق', style: const TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('برای پروژه: ${app['project_title']}', style: const TextStyle(color: Color(0xFF1E6AFB), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${app['student_university']} • ${app['student_major']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 12),

                  // دکمه‌های اکشن
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // ۱. دکمه آکاردئونی بدون آیکون فلش
                      OutlinedButton(
                        onPressed: toggleExpand,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E6AFB),
                          side: const BorderSide(color: Color(0xFF1E6AFB)),
                        ),
                        child: Text(
                          isExpanded ? 'بستن سوابق دانشجو' : 'مشاهده سوابق و رزومه دانشجو',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // ۲. دکمه دعوت به مصاحبه حضوری
                      ElevatedButton.icon(
                        onPressed: () => _showScheduleModal(appId),
                        icon: const Icon(Icons.event_available, size: 14),
                        label: Text(isShortlisted ? 'ویرایش مصاحبه' : 'دعوت به مصاحبه حضوری', style: const TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      ),

                      // ۳. دکمه شروع چت
                      OutlinedButton.icon(
                        onPressed: () => _openChat(appId),
                        icon: const Icon(Icons.chat, size: 14),
                        label: const Text('شروع چت', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🔽 پانل کشویی و بازشونده زیر کارت
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // شماره تماس
                  Row(
                    children: [
                      const Icon(Icons.phone_android_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('شماره همراه: ${app['student_phone'] ?? "ثبت نشده"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // سوابق تحصیلی
                  const Text('🎓 سوابق تحصیلی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E6AFB))),
                  const SizedBox(height: 6),
                  if (educations.isEmpty)
                    const Text('سابقه تحصیلی ثبت نشده است.', style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    ...educations.map((edu) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Text('${edu['degree']} ${edu['major']} - ${edu['university']} (${edu['start_year']} تا ${edu['end_year']}) - معدل: ${edu['gpa']}', style: const TextStyle(fontSize: 11)),
                    )),

                  const SizedBox(height: 12),

                  // سوابق شغلی
                  const Text('💼 سوابق شغلی و کاری:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981))),
                  const SizedBox(height: 6),
                  if (workExp.isEmpty)
                    const Text('سابقه کاری ثبت نشده است.', style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    ...workExp.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Text('${w['position']} در ${w['company']} (${w['from_year']} تا ${w['to_year']})', style: const TextStyle(fontSize: 11)),
                    )),

                  const SizedBox(height: 12),

                  // مهارت‌ها
                  if (skills.isNotEmpty) ...[
                    const Text('🛠️ مهارت‌های تخصصی:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 9)), backgroundColor: Colors.white)).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // پیام دانشجو
                  if (studentMsg != null && studentMsg.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'پیام دانشجو: $studentMsg',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 📄 دکمه مشاهده و دانلود مستقیم فایل PDF رزومه
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _openResumePdf(app['student_resume']),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('مشاهده و دانلود فایل PDF رزومه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.projectTitle != null
        ? 'متقاضیان پروژه: ${widget.projectTitle}'
        : 'مدیریت درخواست‌ها و رزومه‌ها';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(pageTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : _applications.isEmpty
            ? const Center(
          child: Text('هنوز هیچ درخواستی برای این پروژه ارسال نشده است.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _applications.length,
          itemBuilder: (context, index) {
            return _buildApplicantCard(_applications[index]);
          },
        ),
      ),
    );
  }
}