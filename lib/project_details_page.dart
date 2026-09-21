import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employer_applications_page.dart';
import 'student_profile_page.dart';

/// Project details with match score and apply action.
class ProjectDetailsPage extends StatefulWidget {
  final dynamic project;
  final bool isCompany;

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

  // Required profile fields the student still has to fill in before applying.
  // Null until known; the server enforces the rule either way.
  List<String>? _missingFields;

  @override
  void initState() {
    super.initState();
    _isApplied = widget.project['is_applied'] ?? false;
    if (!widget.isCompany) _loadMissingFields();
  }

  Future<void> _loadMissingFields() async {
    final prefs = await SharedPreferences.getInstance();
    final me = await ApiService.getMe(prefs.getString('access_token') ?? '');
    final missing = me?['profile']?['missing_required_fields'];
    if (!mounted || me == null) return;
    setState(() {
      _missingFields = missing is List
          ? missing.map((e) => e.toString()).toList()
          // No profile at all: everything required is missing.
          : (me['profile'] == null ? ['نام و نام خانوادگی', 'حداقل یک سابقه تحصیلی کامل (دانشگاه، رشته و معدل)'] : <String>[]);
    });
  }

  Future<void> _openProfileEditor() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentProfilePage()));
    // Back from editing: check again whether applying is allowed now.
    if (mounted) await _loadMissingFields();
  }

  Future<void> _handleApply() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    setState(() => _isApplying = true);

    final error = await ApiService.applyForProject(
      token,
      widget.project['id'].toString(),
      message: _messageController.text.trim(),
    );

    setState(() => _isApplying = false);

    if (error == null && mounted) {
      setState(() => _isApplied = true);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست و پیام شما با موفقیت ارسال شد.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!), backgroundColor: Colors.redAccent),
      );
      // The server may know about a missing field this page didn't; refresh the note.
      _loadMissingFields();
    }
  }

  /// Asks the student for an optional message before applying.
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
                    const Expanded(child: Text('ارسال درخواست همکاری (اپلای)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
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
                    // Location and deadline sit side by side, and wrap onto two lines on narrow phones.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(child: Text('مکان: $city', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Flexible(child: Text('مهلت ارسال رزومه: $deadline', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),

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

          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isCompany && !_isApplied && (_missingFields?.isNotEmpty ?? false)) _buildMissingFieldsNote(),
                SizedBox(
              height: 48,
              child: widget.isCompany
                  ? ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployerApplicationsPage(
                        projectId: widget.project['id'].toString(),
                        projectTitle: widget.project['title'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people, size: 18),
                label: const Text('مشاهده متقاضیان و رزومه‌های این پروژه', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
                  : (!_isApplied && (_missingFields?.isNotEmpty ?? false))
                  ? _buildCompleteProfileButton()
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
              ],
            ),
          )
      ),
    );
  }

  Widget _buildCompleteProfileButton() {
    return ElevatedButton.icon(
      onPressed: _openProfileEditor,
      icon: const Icon(Icons.person_outline_rounded, size: 18),
      label: const Text('تکمیل پروفایل برای ارسال درخواست', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Above the bottom button while applying is locked: what's missing, in plain words.
  Widget _buildMissingFieldsNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'برای ارسال درخواست، ابتدا این موارد را در پروفایل تکمیل کنید:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._missingFields!.map((f) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $f', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
              )),
        ],
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