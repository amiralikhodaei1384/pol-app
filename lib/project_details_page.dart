import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectDetailsPage extends StatefulWidget {
  final dynamic project;
  final bool isCompany; // تعیین نقش کاربر (دانشجو یا کارفرما)

  const ProjectDetailsPage({
    super.key,
    required this.project,
    this.isCompany = false,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  bool _isApplying = false;
  late bool _isApplied;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isApplied = widget.project['is_applied'] ?? false;
  }

  Future<void> _handleApply() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    setState(() => _isApplying = true);

    final success = await ApiService.applyForProject(
      token,
      widget.project['id'].toString(),
    );

    setState(() => _isApplying = false);

    if (success && mounted) {
      setState(() => _isApplied = true);
      Navigator.pop(context); // بستن دیالوگ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست شما با موفقیت ارسال شد و در انتظار بررسی است.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در ارسال درخواست یا درخواست قبلاً ثبت شده است.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showApplyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ارسال درخواست همکاری (اپلای)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'پیام کوتاه برای کارفرما (اختیاری):',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'توضیح کوتاهی از علاقه‌مندی یا نمونه‌کارهای مرتبط بنویسید...',
                    hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : _handleApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isApplying
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('تأیید و ارسال رزومه نهایی', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final title = project['title'] ?? 'عنوان فرصت شغلی';
    final company = project['company_name'] ?? 'شرکت فناوری';
    final companyAbout = project['company_about'] ?? 'توضیحاتی درباره معرفی این شرکت ثبت نشده است.';
    final companyWebsite = project['company_website'] ?? '';
    final description = project['description'] ?? 'توضیحات در دسترس نیست.';
    final projectType = project['project_type'] ?? 'پروژه';
    final city = project['city'] ?? 'تهران';
    final category = project['category'] ?? 'توسعه نرم‌افزار';
    final deadline = project['deadline'] != null ? project['deadline'].toString().split('T')[0] : 'نامشخص';

    final skills = (project['required_skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final targetUnivs = (project['target_universities'] as List<dynamic>?)?.cast<String>() ?? [];
    final targetMajors = (project['target_majors'] as List<dynamic>?)?.cast<String>() ?? [];
    final matchScore = project['match_score'] ?? 80;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Text('جزئیات فرصت شغلی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ۱. کارت هدر اصلی فرصت شغلی (Jobinja Header)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                          child: Text(projectType, style: const TextStyle(color: Color(0xFF1976D2), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Text(company, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.4)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('مکان: $city', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('مهلت ارسال رزومه: $deadline', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ۲. کارت تطبیق هوشمند (مخصوص دانشجو)
              if (!widget.isCompany) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFE0F2FE)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: matchScore / 100,
                              strokeWidth: 6,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                          Text('$matchScore٪', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تطابق هوشمند رزومه شما با این موقعیت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46))),
                            const SizedBox(height: 4),
                            Text(
                              'بر اساس دانشگاه، رشته تحصیلی، نمرات و مهارت‌های شما محاسبه شده است.',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ۳. کارت مشخصات کلیدی شغلی (جابینجایی)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اطلاعات کلیدی فرصت شغلی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const Divider(height: 20),
                    _buildSpecRow(Icons.category_outlined, 'دسته‌بندی شغلی:', category),
                    const SizedBox(height: 10),
                    _buildSpecRow(
                      Icons.school_outlined,
                      'رشته‌های مرتبط:',
                      targetMajors.isNotEmpty ? targetMajors.join(' ، ') : 'تمام رشته‌های تحصیلی',
                    ),
                    const SizedBox(height: 10),
                    _buildSpecRow(
                      Icons.account_balance_outlined,
                      'دانشگاه‌های اولویت‌دار:',
                      targetUnivs.isNotEmpty ? targetUnivs.join(' ، ') : 'تمام دانشگاه‌ها',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ۴. مهارت‌های مورد نیاز
              const Text('مهارت‌های مورد نیاز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(skill, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ۵. شرح وظایف و انتشارات
              const Text('شرح وظایف و خروجی مورد انتظار', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF475569)),
                ),
              ),

              const SizedBox(height: 24),

              // ۶. 🏢 درباره شرکت (Jobinja About Company Section)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, color: Color(0xFF1E6AFB), size: 20),
                        const SizedBox(width: 8),
                        Text('درباره $company', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      companyAbout,
                      style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF475569)),
                    ),
                    if (companyWebsite.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('وب‌سایت: $companyWebsite', style: const TextStyle(fontSize: 11, color: Color(0xFF1E6AFB))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),

        // دکمه ثابت پایین صفحه
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: SizedBox(
            height: 48,
            child: widget.isCompany
                ? Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
              child: const Text('این فرصت شغلی توسط شما منتشر شده است', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
            )
                : ElevatedButton(
              onPressed: _isApplied ? null : _showApplyDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isApplied ? Colors.grey : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isApplied ? 'درخواست ارسال شده است' : 'ارسال درخواست و رزومه (اپلای)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}