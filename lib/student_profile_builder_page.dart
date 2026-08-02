import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfileBuilderPage extends StatefulWidget {
  const StudentProfileBuilderPage({super.key});

  @override
  State<StudentProfileBuilderPage> createState() => _StudentProfileBuilderPageState();
}

class _StudentProfileBuilderPageState extends State<StudentProfileBuilderPage> {
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  // گام ۱: اطلاعات تحصیلی
  final _fullNameController = TextEditingController();
  final _universityController = TextEditingController();
  final _majorController = TextEditingController();
  final _entranceYearController = TextEditingController();

  // گام ۲: مهارت‌ها و نمرات دروس
  final _skillController = TextEditingController();
  List<String> _skills = [];

  final _courseNameController = TextEditingController();
  final _courseGradeController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];

  // گام ۳: پورتفولیو
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isNotEmpty) {
      final userData = await ApiService.getMe(token);
      if (userData != null && userData['profile'] != null) {
        final p = userData['profile'];
        _fullNameController.text = p['full_name'] ?? '';
        _universityController.text = p['university'] ?? 'دانشگاه تهران';
        _majorController.text = p['major'] ?? 'مهندسی کامپیوتر';
        _entranceYearController.text = (p['entrance_year'] ?? 1401).toString();

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
      setState(() => _isLoadingProfile = false);
    }
  }

  void _addSkill() {
    final text = _skillController.text.trim();
    if (text.isNotEmpty && !_skills.contains(text)) {
      setState(() {
        _skills.add(text);
        _skillController.clear();
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

  Future<void> _submitProfile() async {
    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً نام و نام خانوادگی را وارد کنید.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پروفایل با موفقیت بروزرسانی شد'), backgroundColor: Colors.green));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage(isCompany: false)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در ذخیره پروفایل'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ویرایش و تکمیل پروفایل دانشجویی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E6AFB),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _submitProfile();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6AFB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_currentStep == 2 ? 'ذخیره و ورود به داشبورد' : 'گام بعدی'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('گام قبلی', style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('تحصیلی', style: TextStyle(fontSize: 12)),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('نام و نام خانوادگی *'),
                  TextField(controller: _fullNameController, decoration: _inputDec('مثال: علی محمدی')),
                  const SizedBox(height: 12),
                  _buildLabel('دانشگاه *'),
                  TextField(controller: _universityController, decoration: _inputDec('مثال: دانشگاه تهران')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('رشته تحصیلی *'),
                            TextField(controller: _majorController, decoration: _inputDec('مهندسی کامپیوتر')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('سال ورود *'),
                            TextField(controller: _entranceYearController, keyboardType: TextInputType.number, decoration: _inputDec('1401')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('مهارت و نمرات', style: TextStyle(fontSize: 12)),
              isActive: _currentStep >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('افزودن مهارت‌ها'),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _skillController, decoration: _inputDec('مثال: React, Figma'))),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _addSkill, child: const Text('افزودن')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _skills.map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s)))).toList(),
                  ),
                  const Divider(height: 32),
                  _buildLabel('دروس تخصصی گذرا‌نده‌شده و نمره (برای تطبیق هوشمند)'),
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: _courseNameController, decoration: _inputDec('نام درس (مثال: ساختمان داده)'))),
                      const SizedBox(width: 8),
                      Expanded(flex: 1, child: TextField(controller: _courseGradeController, keyboardType: TextInputType.number, decoration: _inputDec('نمره (از ۲۰)'))),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _addCourse, child: const Text('ثبت')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: _courses.map((c) {
                      return Card(
                        child: ListTile(
                          title: Text(c['course_name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          trailing: Text('نمره: ${c['grade']}', style: const TextStyle(color: Color(0xFF1E6AFB), fontWeight: FontWeight.bold)),
                          leading: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            onPressed: () => setState(() => _courses.remove(c)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('پورتفولیو', style: TextStyle(fontSize: 12)),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('لینک گیت‌هاب (GitHub)'),
                  TextField(controller: _githubController, decoration: _inputDec('https://github.com/username')),
                  const SizedBox(height: 12),
                  _buildLabel('لینک فیگما / نمونه‌کار (Figma)'),
                  TextField(controller: _figmaController, decoration: _inputDec('https://figma.com/@username')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}