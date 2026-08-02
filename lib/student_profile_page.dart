import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;

  // فیلدهای متنی
  final _fullNameController = TextEditingController();
  final _universityController = TextEditingController();
  final _majorController = TextEditingController();
  final _entranceYearController = TextEditingController();
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();

  // مهارت‌ها
  final _skillInputController = TextEditingController();
  List<String> _skills = [];

  // دروس و نمره‌ها
  final _courseNameController = TextEditingController();
  final _courseGradeController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isNotEmpty) {
      final userData = await ApiService.getMe(token);
      if (userData != null && userData['profile'] != null) {
        final p = userData['profile'];
        _fullNameController.text = p['full_name'] ?? '';
        _universityController.text = p['university'] ?? '';
        _majorController.text = p['major'] ?? '';
        _entranceYearController.text = p['entrance_year'] != null ? p['entrance_year'].toString() : '';

        if (p['skills'] != null) {
          _skills = (p['skills'] as List<dynamic>).cast<String>();
        }
        if (p['courses'] != null) {
          _courses = (p['courses'] as List<dynamic>).map((c) {
            return {
              'course_name': c['course_name'] ?? c['course'] ?? '',
              'grade': (c['grade'] as num).toDouble(),
            };
          }).toList();
        }
        if (p['portfolio_links'] != null) {
          _githubController.text = p['portfolio_links']['github'] ?? '';
          _figmaController.text = p['portfolio_links']['figma'] ?? '';
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _addSkill() {
    final text = _skillInputController.text.trim();
    if (text.isNotEmpty && !_skills.contains(text)) {
      setState(() {
        _skills.add(text);
        _skillInputController.clear();
      });
    }
  }

  void _addCourse() {
    final name = _courseNameController.text.trim();
    final gradeText = _courseGradeController.text.trim();
    if (name.isNotEmpty && gradeText.isNotEmpty) {
      final grade = double.tryParse(gradeText);
      if (grade != null && grade >= 0 && grade <= 20) {
        setState(() {
          _courses.add({'course_name': name, 'grade': grade});
          _courseNameController.clear();
          _courseGradeController.clear();
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام و نام خانوادگی را وارد کنید.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final success = await ApiService.saveStudentProfile(
      token: token,
      fullName: _fullNameController.text.trim(),
      university: _universityController.text.trim(),
      major: _majorController.text.trim(),
      entranceYear: int.tryParse(_entranceYearController.text.trim()) ?? 1401,
      skills: _skills,
      courses: _courses,
      githubLink: _githubController.text.trim(),
      figmaLink: _figmaController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تغییرات پروفایل با موفقیت ذخیره شد'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true); // بازگشت به داشبورد
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در ذخیره تغییرات'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
          title: const Text(
            'پروفایل من',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E6AFB)),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // کارت هدر شیک بالایی
              _buildTopHeaderCard(),
              const SizedBox(height: 20),

              // ۱. اطلاعات تحصیلی و فردی
              _buildSectionContainer(
                title: 'اطلاعات فردی و تحصیلی',
                icon: Icons.school_outlined,
                accentColor: const Color(0xFF1E6AFB), // آبی
                children: [
                  _buildMinimalField(
                    label: 'نام و نام خانوادگی',
                    controller: _fullNameController,
                    hint: 'وارد نشده',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _buildMinimalField(
                    label: 'دانشگاه',
                    controller: _universityController,
                    hint: 'وارد نشده (مثال: دانشگاه تهران)',
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMinimalField(
                          label: 'رشته تحصیلی',
                          controller: _majorController,
                          hint: 'وارد نشده',
                          icon: Icons.menu_book_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMinimalField(
                          label: 'سال ورود',
                          controller: _entranceYearController,
                          hint: 'مثال: 1401',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ۲. مهارت‌ها
              _buildSectionContainer(
                title: 'مهارت‌های تخصصی',
                icon: Icons.workspace_premium_outlined,
                accentColor: const Color(0xFF10B981), // سبز
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMinimalField(
                          label: 'افزودن مهارت جدید',
                          controller: _skillInputController,
                          hint: 'مثال: Flutter, Python, Figma',
                          icon: Icons.add_task_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: ElevatedButton(
                          onPressed: _addSkill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('افزودن'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_skills.isEmpty)
                    const Text('مهارتی ثبت نشده است.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills.map((skill) {
                        return Chip(
                          label: Text(skill,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B))),
                          backgroundColor: const Color(0xFFECFDF5),
                          side: const BorderSide(
                              color: Color(0xFFA7F3D0)),
                          deleteIcon: const Icon(Icons.close,
                              size: 14, color: Color(0xFF047857)),
                          onDeleted: () =>
                              setState(() => _skills.remove(skill)),
                        );
                      }).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ۳. دروس و نمرات (سیستم تطبیق)
              _buildSectionContainer(
                title: 'دروس گذرانده‌شده و نمرات',
                icon: Icons.bar_chart_rounded,
                accentColor: const Color(0xFF1E6AFB), // آبی
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildMinimalField(
                          label: 'نام درس',
                          controller: _courseNameController,
                          hint: 'مثال: ساختمان داده',
                          icon: Icons.book_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: _buildMinimalField(
                          label: 'نمره (از ۲۰)',
                          controller: _courseGradeController,
                          hint: '۱۹.۵',
                          icon: Icons.grade_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: ElevatedButton(
                          onPressed: _addCourse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6AFB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('ثبت'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_courses.isEmpty)
                    const Text('درسی ثبت نشده است.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey))
                  else
                    Column(
                      children: _courses.map((course) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Text(course['course_name'],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      'نمره: ${course['grade']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E6AFB)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.redAccent),
                                    onPressed: () => setState(() =>
                                        _courses.remove(course)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ۴. نمونه‌کارها و پورتفولیو
              _buildSectionContainer(
                title: 'پورتفولیو و شبکه‌های حرفه‌ای',
                icon: Icons.link_rounded,
                accentColor: const Color(0xFF10B981), // سبز
                children: [
                  _buildMinimalField(
                    label: 'لینک گیت‌هاب (GitHub)',
                    controller: _githubController,
                    hint: 'https://github.com/username',
                    icon: Icons.code_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildMinimalField(
                    label: 'لینک فیگما یا نمونه‌کار (Figma)',
                    controller: _figmaController,
                    hint: 'https://figma.com/@username',
                    icon: Icons.brush_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // دکمه شیک انتهای صفحه برای ذخیره تغییرات
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ویجت بالایی شامل آواتار و خلاصه نام
  Widget _buildTopHeaderCard() {
    final name = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : 'دانشجوی پل';
    final uni = _universityController.text.isNotEmpty
        ? _universityController.text
        : 'دانشگاه تعیین نشده';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E6AFB), Color(0xFF10B981)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6AFB).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              name.isNotEmpty ? name[0] : 'د',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E6AFB)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  uni,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'پروفایل فعال',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  // کانتینر استاندارد بخش‌ها
  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  // کادر ورودی‌های متنی مینیمال
  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              const BorderSide(color: Color(0xFF1E6AFB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // دکمه ذخیره هیبریدی
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E6AFB), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'ذخیره تغییرات پروفایل',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}