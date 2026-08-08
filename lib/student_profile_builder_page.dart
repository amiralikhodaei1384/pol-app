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

  // ۱. اطلاعات فردی
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _residenceController = TextEditingController();
  final _birthPlaceController = TextEditingController();

  // سوابق تحصیلی
  final List<Map<String, dynamic>> _educations = [];

  // ۲. سوابق کاری
  final List<Map<String, dynamic>> _workExperiences = [];

  // ۳. مهارت‌ها و نمرات دروس (بدون دیفالت)
  final _skillController = TextEditingController();
  List<String> _skills = [];

  final _courseNameController = TextEditingController();
  final _courseGradeController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];

  // ۴. پورتفولیو و رزومه
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();
  String? _resumeFileName;

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
        final fullName = (p['full_name'] ?? '').toString().split(' ');
        if (fullName.isNotEmpty) _firstNameController.text = fullName.first;
        if (fullName.length > 1) _lastNameController.text = fullName.sublist(1).join(' ');

        _phoneController.text = p['phone'] ?? '';
        _birthDateController.text = p['birth_date'] ?? '';
        _residenceController.text = p['residence'] ?? '';
        _birthPlaceController.text = p['birth_place'] ?? '';

        if (p['skills'] != null && p['skills'] is List) {
          _skills = (p['skills'] as List<dynamic>).cast<String>();
        }
        if (p['courses'] != null && p['courses'] is List) {
          _courses = (p['courses'] as List<dynamic>).map((c) {
            return {
              'course_name': c['course_name'] ?? c['course'] ?? '',
              'grade': (c['grade'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList();
        }
        if (p['educations'] != null && p['educations'] is List) {
          _educations.clear();
          for (var item in p['educations']) {
            if (item is Map) {
              _educations.add(Map<String, dynamic>.from(item));
            }
          }
        }
        if (p['work_experiences'] != null && p['work_experiences'] is List) {
          _workExperiences.clear();
          for (var item in p['work_experiences']) {
            if (item is Map) {
              _workExperiences.add(Map<String, dynamic>.from(item));
            }
          }
        }
        if (p['portfolio_links'] != null) {
          _githubController.text = p['portfolio_links']['github'] ?? '';
          _figmaController.text = p['portfolio_links']['figma'] ?? '';
        }
        _resumeFileName = p['resume_file'];
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

  // دیالوگ افزودن مقطع تحصیلی با تیک «در حال تحصیل هستم»
  void _showAddEducationDialog() {
    String degree = 'کارشناسی';
    final universityCtrl = TextEditingController();
    final majorCtrl = TextEditingController();
    final startYearCtrl = TextEditingController();
    final endYearCtrl = TextEditingController();
    final gpaCtrl = TextEditingController();
    bool isCurrentlyStudying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20, left: 20, right: 20,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('افزودن مقطع تحصیلی جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      _buildLabel('مقطع تحصیلی'),
                      DropdownButtonFormField<String>(
                        value: degree,
                        decoration: _inputDec('انتخاب مقطع'),
                        items: ['کاردانی', 'کارشناسی', 'کارشناسی ارشد', 'دکتری'].map((d) {
                          return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) => degree = val ?? degree,
                      ),
                      const SizedBox(height: 12),
                      _buildLabel('نام دانشگاه'),
                      TextField(controller: universityCtrl, decoration: _inputDec('مثال: دانشگاه تهران')),
                      const SizedBox(height: 12),
                      _buildLabel('رشته تحصیلی'),
                      TextField(controller: majorCtrl, decoration: _inputDec('مثال: مهندسی کامپیوتر')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('سال ورود'),
                                TextField(controller: startYearCtrl, keyboardType: TextInputType.number, decoration: _inputDec('1400')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('سال خروج'),
                                TextField(
                                  controller: endYearCtrl,
                                  enabled: !isCurrentlyStudying,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDec(isCurrentlyStudying ? 'در حال تحصیل' : '1404'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('معدل'),
                                TextField(controller: gpaCtrl, keyboardType: TextInputType.number, decoration: _inputDec('18.5')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: isCurrentlyStudying,
                        activeColor: const Color(0xFF1E6AFB),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('هنوز در حال تحصیل در این مقطع هستم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onChanged: (val) {
                          setModalState(() {
                            isCurrentlyStudying = val ?? false;
                            if (isCurrentlyStudying) {
                              endYearCtrl.text = 'در حال تحصیل';
                            } else {
                              endYearCtrl.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            if (universityCtrl.text.isNotEmpty && majorCtrl.text.isNotEmpty) {
                              setState(() {
                                _educations.add({
                                  'degree': degree,
                                  'university': universityCtrl.text.trim(),
                                  'major': majorCtrl.text.trim(),
                                  'start_year': startYearCtrl.text.trim(),
                                  'end_year': isCurrentlyStudying ? 'در حال تحصیل' : endYearCtrl.text.trim(),
                                  'gpa': gpaCtrl.text.trim(),
                                });
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6AFB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('ثبت سابقه تحصیلی', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // دیالوگ افزودن سابقه کاری با تیک «مشغول به کار هستم»
  void _showAddWorkDialog() {
    final companyCtrl = TextEditingController();
    final positionCtrl = TextEditingController();
    final startYearCtrl = TextEditingController();
    final endYearCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isCurrentlyWorking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20, left: 20, right: 20,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('افزودن سابقه شغلی جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      _buildLabel('نام شرکت / سازمان'),
                      TextField(controller: companyCtrl, decoration: _inputDec('مثال: اسنپ، همراه اول')),
                      const SizedBox(height: 12),
                      _buildLabel('سمت شغلی'),
                      TextField(controller: positionCtrl, decoration: _inputDec('مثال: توسعه‌دهنده فلاتر')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('از سال'),
                                TextField(controller: startYearCtrl, keyboardType: TextInputType.number, decoration: _inputDec('1401')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('تا سال'),
                                TextField(
                                  controller: endYearCtrl,
                                  enabled: !isCurrentlyWorking,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDec(isCurrentlyWorking ? 'مشغول به کار' : '1402'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: isCurrentlyWorking,
                        activeColor: const Color(0xFF10B981),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('همچنان در این مجموعه مشغول به کار هستم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onChanged: (val) {
                          setModalState(() {
                            isCurrentlyWorking = val ?? false;
                            if (isCurrentlyWorking) {
                              endYearCtrl.text = 'مشغول به کار';
                            } else {
                              endYearCtrl.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildLabel('توضیحات فعالیت (اختیاری)'),
                      TextField(controller: descCtrl, maxLines: 2, decoration: _inputDec('خلاصه‌ای از پروژه‌ها...')),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            if (companyCtrl.text.isNotEmpty && positionCtrl.text.isNotEmpty) {
                              setState(() {
                                _workExperiences.add({
                                  'company': companyCtrl.text.trim(),
                                  'position': positionCtrl.text.trim(),
                                  'from_year': startYearCtrl.text.trim(),
                                  'to_year': isCurrentlyWorking ? 'مشغول به کار' : endYearCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                });
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('ثبت سابقه کاری', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _selectOrChangeResume() {
    final count = DateTime.now().millisecondsSinceEpoch % 1000;
    final name = _firstNameController.text.trim().isNotEmpty ? _firstNameController.text.trim() : 'دانشجو';
    setState(() {
      _resumeFileName = "Resume_${name}_$count.pdf";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فایل رزومه انتخاب شد.'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _submitProfile() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً نام و نام خانوادگی را وارد کنید.')));
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final primaryEdu = _educations.isNotEmpty ? _educations.first : {};
    final uniName = primaryEdu['university'] ?? '';
    final majorName = primaryEdu['major'] ?? '';
    final entranceYear = int.tryParse(primaryEdu['start_year'] ?? '') ?? 1401;

    final success = await ApiService.saveStudentProfile(
      token: token,
      fullName: '$firstName $lastName',
      phone: _phoneController.text.trim(),
      birthDate: _birthDateController.text.trim(),
      residence: _residenceController.text.trim(),
      birthPlace: _birthPlaceController.text.trim(),
      university: uniName,
      major: majorName,
      entranceYear: entranceYear,
      skills: _skills,
      courses: _courses,
      educations: _educations,
      workExperiences: _workExperiences,
      githubLink: _githubController.text.trim(),
      figmaLink: _figmaController.text.trim(),
      resumeFile: _resumeFileName,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پروفایل با موفقیت تکمیل شد'), backgroundColor: Color(0xFF10B981)));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage(isCompany: false)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در ذخیره اطلاعات'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('تکمیل پروفایل دانشجویی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E6AFB),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : Column(
          children: [
            _buildStepProgressHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildCurrentStepContent(),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgressHeader() {
    final titles = ['فردی و تحصیلی', 'سوابق کاری', 'مهارت و دروس', 'رزومه و لینک‌ها'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isDone
                            ? const Color(0xFF10B981)
                            : (isActive ? const Color(0xFF1E6AFB) : const Color(0xFFE2E8F0)),
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titles[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? const Color(0xFF1E6AFB) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < 3)
                  Container(
                    width: 12,
                    height: 2,
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1PersonalAndEducation();
      case 1:
        return _buildStep2WorkExperience();
      case 2:
        return _buildStep3SkillsAndCourses();
      case 3:
        return _buildStep4PortfolioAndResume();
      default:
        return Container();
    }
  }

  Widget _buildEducationList() {
    if (_educations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Text('هنوز سابقه تحصیلی ثبت نشده است. (حداقل یک مقطع ثبت کنید)', style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    return Column(
      children: _educations.map((edu) {
        final degree = edu['degree'] ?? '';
        final major = edu['major'] ?? '';
        final university = edu['university'] ?? '';
        final startYear = edu['start_year'] ?? '';
        final endYear = edu['end_year'] ?? '';
        final gpa = edu['gpa'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.school, size: 20, color: Color(0xFF1E6AFB)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$degree $major', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('$university ($startYear - $endYear) • معدل: $gpa', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => setState(() => _educations.remove(edu)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep1PersonalAndEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'اطلاعات شناسنامه‌ای و فردی',
          icon: Icons.person_outline,
          accentColor: const Color(0xFF1E6AFB),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('نام *'),
                        TextField(controller: _firstNameController, decoration: _inputDec('مثال: علی')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('نام خانوادگی *'),
                        TextField(controller: _lastNameController, decoration: _inputDec('مثال: محمدی')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('شماره همراه'),
                        TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDec('09123456789')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('تاریخ تولد'),
                        TextField(controller: _birthDateController, decoration: _inputDec('مثال: 1380/05/12')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('محل سکونت'),
                        TextField(controller: _residenceController, decoration: _inputDec('مثال: تهران')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('محل تولد'),
                        TextField(controller: _birthPlaceController, decoration: _inputDec('مثال: شیراز')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'سوابق تحصیلی و دانشگاهی',
          icon: Icons.school_outlined,
          accentColor: const Color(0xFF10B981),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEducationList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showAddEducationDialog,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                label: const Text('افزودن مقطع تحصیلی جدید', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 38),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkExperienceList() {
    if (_workExperiences.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('اگر سابقه کار یا کارآموزی قبلی دارید اضافه کنید.', style: TextStyle(fontSize: 11, color: Colors.grey))),
      );
    }

    return Column(
      children: _workExperiences.map((work) {
        final position = work['position'] ?? '';
        final company = work['company'] ?? '';
        final fromYear = work['from_year'] ?? '';
        final toYear = work['to_year'] ?? '';
        final desc = work['description'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.business_center_outlined, size: 20, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$position در $company', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('$fromYear تا $toYear', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (desc.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc.toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ]
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => setState(() => _workExperiences.remove(work)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep2WorkExperience() {
    return _buildSectionCard(
      title: 'سوابق شغلی و کاری (اختیاری)',
      icon: Icons.work_outline,
      accentColor: const Color(0xFF1E6AFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWorkExperienceList(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showAddWorkDialog,
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF1E6AFB)),
            label: const Text('افزودن سابقه کاری جدید', style: TextStyle(fontSize: 11, color: Color(0xFF1E6AFB), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1E6AFB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SkillsAndCourses() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'مهارت‌های تخصصی',
          icon: Icons.star_outline,
          accentColor: const Color(0xFF10B981),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: _skillController, decoration: _inputDec('مثال: Flutter, Python'))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addSkill,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('افزودن'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: _skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11)), onDeleted: () => setState(() => _skills.remove(s)))).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'دروس و نمرات (سیستم تطبیق هوشمند)',
          icon: Icons.grade_outlined,
          accentColor: const Color(0xFF1E6AFB),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: TextField(controller: _courseNameController, decoration: _inputDec('نام درس (مثال: ساختمان داده)'))),
                  const SizedBox(width: 6),
                  Expanded(flex: 1, child: TextField(controller: _courseGradeController, keyboardType: TextInputType.number, decoration: _inputDec('نمره'))),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _addCourse,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6AFB), foregroundColor: Colors.white),
                    child: const Text('ثبت'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: _courses.map((c) {
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(c['course_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      trailing: Text('نمره: ${c['grade'] ?? ''}', style: const TextStyle(color: Color(0xFF1E6AFB), fontWeight: FontWeight.bold, fontSize: 11)),
                      leading: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                        onPressed: () => setState(() => _courses.remove(c)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4PortfolioAndResume() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'شبکه‌های حرفه‌ای و نمونه‌کار',
          icon: Icons.link_outlined,
          accentColor: const Color(0xFF1E6AFB),
          child: Column(
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
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'آپلود فایل رزومه (اختیاری)',
          icon: Icons.upload_file_outlined,
          accentColor: const Color(0xFF10B981),
          child: Column(
            children: [
              InkWell(
                onTap: _selectOrChangeResume,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _resumeFileName != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      Icon(_resumeFileName != null ? Icons.check_circle : Icons.cloud_upload_outlined, size: 36, color: _resumeFileName != null ? const Color(0xFF10B981) : const Color(0xFF1E6AFB)),
                      const SizedBox(height: 8),
                      Text(
                        _resumeFileName ?? 'برای انتخاب یا تغییر فایل رزومه (PDF) کلیک کنید',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _resumeFileName != null ? const Color(0xFF10B981) : Colors.black54),
                      ),
                      if (_resumeFileName == null)
                        const Text('حداکثر حجم ۱۰ مگابایت', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              if (_resumeFileName != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _selectOrChangeResume,
                      icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF1E6AFB)),
                      label: const Text('تعویض فایل رزومه', style: TextStyle(fontSize: 11, color: Color(0xFF1E6AFB))),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _resumeFileName = null),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      label: const Text('حذف فایل', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color accentColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('گام قبلی'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  _submitProfile();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6AFB),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == 3 ? 'تکمیل و ورود به داشبورد' : 'گام بعدی', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}