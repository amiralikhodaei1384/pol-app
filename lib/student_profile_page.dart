import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isUploadingResume = false;

  // ۱. اطلاعات فردی و شناسنامه‌ای
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _residenceController = TextEditingController();
  final _birthPlaceController = TextEditingController();

  // سوابق تحصیلی
  final List<Map<String, dynamic>> _educations = [];

  // سوابق کاری
  final List<Map<String, dynamic>> _workExperiences = [];

  // مهارت‌ها
  final _skillInputController = TextEditingController();
  List<String> _skills = [];

  // دروس و نمره‌ها
  final _courseNameController = TextEditingController();
  final _courseGradeController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];

  // پورتفولیو و رزومه
  final _githubController = TextEditingController();
  final _figmaController = TextEditingController();
  String? _displayResumeName; // نام اصلی فایل جهت نمایش به کاربر
  String? _resumeServerPath;   // مسیر ذخیره فایل در سرور

  // عبارات منظم جهت اعتبارسنجی
  final _persianRegex = RegExp(r'^[\u0600-\u06FF\s]+$');
  final _phoneRegex = RegExp(r'^09\d{9}$');

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

        final rawFullName = (p['full_name'] ?? '').toString().trim();
        if (rawFullName.isNotEmpty && rawFullName != 'دانشجوی جدید') {
          final fullName = rawFullName.split(' ');
          if (fullName.isNotEmpty) _firstNameController.text = fullName.first;
          if (fullName.length > 1) _lastNameController.text = fullName.sublist(1).join(' ');
        }

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
        if (p['resume_file'] != null && p['resume_file'].toString().isNotEmpty) {
          final serverPath = p['resume_file'].toString();
          _resumeServerPath = serverPath;
          // استخراج نام فایل پی‌دی‌اف از آدرس سرور جهت نمایش
          _displayResumeName = serverPath.split('/').last;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
      ),
    );
  }

  // انتخاب فقط فایل PDF
  Future<void> _pickAndUploadResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (!file.name.toLowerCase().endsWith('.pdf')) {
          _showSnack('لطفاً تنها فایل با فرمت PDF انتخاب کنید.');
          return;
        }

        if (file.bytes != null) {
          setState(() => _isUploadingResume = true);

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token') ?? '';

          final savedPath = await ApiService.uploadResume(
            token: token,
            fileBytes: file.bytes!,
            fileName: file.name,
          );

          setState(() => _isUploadingResume = false);

          if (savedPath != null) {
            setState(() {
              _displayResumeName = file.name; // نمایش نام اصلی پی‌دی‌اف انتخابی کاربر
              _resumeServerPath = savedPath;   // آدرس سرور
            });
            _showSnack('فایل رزومه PDF با موفقیت ذخیره شد.', isError: false);
          }
        }
      }
    } catch (e) {
      setState(() => _isUploadingResume = false);
      print("خطا در انتخاب فایل: $e");
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
      } else {
        _showSnack('نمره باید عددی بین ۰ تا ۲۰ باشد.');
      }
    }
  }

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
                      TextField(
                        controller: universityCtrl,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'))],
                        decoration: _inputDec('مثال: دانشگاه تهران'),
                      ),
                      const SizedBox(height: 12),
                      _buildLabel('رشته تحصیلی'),
                      TextField(
                        controller: majorCtrl,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'))],
                        decoration: _inputDec('مثال: مهندسی کامپیوتر'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('سال ورود'),
                                TextField(
                                  controller: startYearCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: _inputDec('مثال: 1400').copyWith(counterText: ''),
                                ),
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
                                  maxLength: 4,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: _inputDec(isCurrentlyStudying ? 'در حال تحصیل' : 'مثال: 1404').copyWith(counterText: ''),
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
                                TextField(
                                  controller: gpaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                                  decoration: _inputDec('مثال: 18.5'),
                                ),
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
                            final gpa = double.tryParse(gpaCtrl.text.trim());
                            if (universityCtrl.text.isEmpty || majorCtrl.text.isEmpty) {
                              _showSnack('نام دانشگاه و رشته تحصیلی الزامی است.');
                              return;
                            }
                            if (gpa != null && (gpa < 0 || gpa > 20)) {
                              _showSnack('معدل باید عددی بین ۰ تا ۲۰ باشد.');
                              return;
                            }

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
                                TextField(
                                  controller: startYearCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: _inputDec('مثال: 1401').copyWith(counterText: ''),
                                ),
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
                                  maxLength: 4,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: _inputDec(isCurrentlyWorking ? 'مشغول به کار' : 'مثال: 1402').copyWith(counterText: ''),
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
                            if (companyCtrl.text.isEmpty || positionCtrl.text.isEmpty) {
                              _showSnack('نام شرکت و سمت شغلی الزامی است.');
                              return;
                            }
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

  Future<void> _saveChanges() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnack('لطفاً نام و نام خانوادگی را وارد کنید.');
      return;
    }
    if (!_persianRegex.hasMatch(firstName) || !_persianRegex.hasMatch(lastName)) {
      _showSnack('نام و نام خانوادگی باید فقط شامل حروف فارسی باشد.');
      return;
    }
    if (phone.isNotEmpty && !_phoneRegex.hasMatch(phone)) {
      _showSnack('شماره همراه باید ۱۱ رقم بوده و با ۰۹ شروع شود.');
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
      phone: phone,
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
      resumeFile: _resumeServerPath,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      _showSnack('تغییرات پروفایل با موفقیت ذخیره شد', isError: false);
      Navigator.pop(context, true); // بازگشت به داشبورد
    } else if (mounted) {
      _showSnack('خطا در ذخیره تغییرات');
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
          title: const Text('ویرایش و مشاهده پروفایل من', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildTopHeaderCard(),
              const SizedBox(height: 20),

              // ۱. اطلاعات شناسنامه‌ای و فردی
              _buildSectionContainer(
                title: 'اطلاعات شناسنامه‌ای و فردی',
                icon: Icons.person_outline,
                accentColor: const Color(0xFF1E6AFB),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMinimalField(
                          label: 'نام (فارسی) *',
                          controller: _firstNameController,
                          hint: 'وارد نشده',
                          icon: Icons.person_outline,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'))],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMinimalField(
                          label: 'نام خانوادگی (فارسی) *',
                          controller: _lastNameController,
                          hint: 'وارد نشده',
                          icon: Icons.person_outline,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'))],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMinimalField(
                          label: 'شماره همراه',
                          controller: _phoneController,
                          hint: '09123456789',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMinimalField(
                          label: 'تاریخ تولد',
                          controller: _birthDateController,
                          hint: '1380/05/12',
                          icon: Icons.cake_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMinimalField(
                          label: 'محل سکونت',
                          controller: _residenceController,
                          hint: 'مثال: تهران',
                          icon: Icons.home_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMinimalField(
                          label: 'محل تولد',
                          controller: _birthPlaceController,
                          hint: 'مثال: شیراز',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ۲. سوابق تحصیلی
              _buildSectionContainer(
                title: 'سوابق تحصیلی و دانشگاهی',
                icon: Icons.school_outlined,
                accentColor: const Color(0xFF10B981),
                children: [
                  _buildEducationList(),
                  const SizedBox(height: 10),
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
              const SizedBox(height: 20),

              // ۳. سوابق شغلی
              _buildSectionContainer(
                title: 'سوابق شغلی و کاری (اختیاری)',
                icon: Icons.work_outline,
                accentColor: const Color(0xFF1E6AFB),
                children: [
                  _buildWorkExperienceList(),
                  const SizedBox(height: 10),
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
              const SizedBox(height: 20),

              // ۴. مهارت‌های تخصصی
              _buildSectionContainer(
                title: 'مهارت‌های تخصصی',
                icon: Icons.workspace_premium_outlined,
                accentColor: const Color(0xFF10B981),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('افزودن'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_skills.isEmpty)
                    const Text('مهارتی ثبت نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills.map((skill) {
                        return Chip(
                          label: Text(skill, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          backgroundColor: const Color(0xFFECFDF5),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF047857)),
                          onDeleted: () => setState(() => _skills.remove(skill)),
                        );
                      }).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ۵. دروس و نمرات
              _buildSectionContainer(
                title: 'دروس گذرانده‌شده و نمرات',
                icon: Icons.bar_chart_rounded,
                accentColor: const Color(0xFF1E6AFB),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('ثبت'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_courses.isEmpty)
                    const Text('درسی ثبت نشده است.', style: TextStyle(fontSize: 11, color: Colors.grey))
                  else
                    Column(
                      children: _courses.map((course) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Text(course['course_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                                    child: Text('نمره: ${course['grade']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => setState(() => _courses.remove(course)),
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

              // ۶. پورتفولیو و رزومه
              _buildSectionContainer(
                title: 'پورتفولیو و فایل رزومه (فقط PDF)',
                icon: Icons.link_rounded,
                accentColor: const Color(0xFF10B981),
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
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _isUploadingResume ? null : _pickAndUploadResume,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _displayResumeName != null ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _displayResumeName != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                      ),
                      child: _isUploadingResume
                          ? const Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF1E6AFB)),
                          SizedBox(height: 8),
                          Text('در حال آپلود فایل روی سرور...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      )
                          : Column(
                        children: [
                          Icon(_displayResumeName != null ? Icons.picture_as_pdf : Icons.cloud_upload_outlined, size: 36, color: _displayResumeName != null ? const Color(0xFF10B981) : const Color(0xFF1E6AFB)),
                          const SizedBox(height: 8),
                          Text(
                            _displayResumeName ?? 'برای انتخاب یا تغییر فایل رزومه (فقط PDF) کلیک کنید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _displayResumeName != null ? const Color(0xFF047857) : Colors.black54,
                            ),
                          ),
                          if (_displayResumeName == null)
                            const Text('تنها فرمت PDF مجاز است (حداکثر ۱۰ مگابایت)', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  if (_displayResumeName != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _pickAndUploadResume,
                          icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF1E6AFB)),
                          label: const Text('تعویض و انتخاب فایل جدید', style: TextStyle(fontSize: 11, color: Color(0xFF1E6AFB))),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _displayResumeName = null;
                            _resumeServerPath = null;
                          }),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          label: const Text('حذف فایل', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),

              // دکمه ذخیره نهایی
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard() {
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    final primaryEdu = _educations.isNotEmpty ? _educations.first : {};
    final uni = primaryEdu['university'] ?? 'دانشگاه تعیین نشده';

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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'دانشجوی کارمَچ',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            child: const Text('پروفایل فعال', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E6AFB), width: 1.5)),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
        ),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'ذخیره تغییرات پروفایل',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}