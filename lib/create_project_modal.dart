import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pol_app/api_service.dart';

class CreateProjectModal extends StatefulWidget {
  const CreateProjectModal({super.key});

  @override
  State<CreateProjectModal> createState() => _CreateProjectModalState();
}

class _CreateProjectModalState extends State<CreateProjectModal> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _skillInputController = TextEditingController();

  // Form State (بدون پیش‌فرض‌های هاردکد شده)
  String? _selectedProjectType; // پروژه / کارآموزی / امریه
  String? _selectedCity;
  String? _selectedCategory;

  List<String> _selectedUniversities = [];
  List<String> _selectedMajors = [];

  List<String> _cities = ['تهران', 'اصفهان', 'شیراز', 'مشهد', 'تبریز', 'کرج', 'اهواز', 'قم', 'رشت', 'دورکاری'];
  List<String> _categories = ['توسعه نرم‌افزار', 'طراحی UI/UX', 'دیجیتال مارکتینگ', 'هوش مصنوعی و داده', 'شبکه و امنیت', 'مدیریت و صنایع'];
  List<String> _allUniversities = ['دانشگاه تهران', 'دانشگاه صنعتی شریف', 'دانشگاه صنعتی امیرکبیر', 'دانشگاه علم و صنعت', 'دانشگاه شهید بهشتی', 'سایر'];
  List<String> _allMajors = ['مهندسی کامپیوتر', 'مهندسی برق', 'مهندسی صنایع', 'مهندسی مکانیک', 'علوم کامپیوتر', 'سایر'];

  final List<String> _skillsList = [];
  DateTime? _selectedDeadline;
  bool _requiresInterview = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final opts = await ApiService.fetchOptions();
    if (opts != null && mounted) {
      setState(() {
        if (opts['cities'] != null) _cities = (opts['cities'] as List).cast<String>();
        if (opts['categories'] != null) _categories = (opts['categories'] as List).cast<String>();
        if (opts['universities'] != null) _allUniversities = (opts['universities'] as List).cast<String>();
        if (opts['majors'] != null) _allMajors = (opts['majors'] as List).cast<String>();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final text = _skillInputController.text.trim();
    if (text.isNotEmpty && !_skillsList.contains(text)) {
      setState(() {
        _skillsList.add(text);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skillsList.remove(skill);
    });
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submitProject() async {
    // ۱. اگر متنی در کادر مهارت مانده، خودکار اضافه کن
    if (_skillInputController.text.trim().isNotEmpty) {
      _addSkill();
    }

    // ۲. اعتبارسنجی ورودی‌های متنی
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ۳. بررسی تفکیک‌شده فیلدها با پیام‌های خطای مشخص
    if (_selectedProjectType == null) {
      _showSnack('لطفاً «نوع همکاری» را انتخاب کنید.');
      return;
    }

    if (_selectedCity == null) {
      _showSnack('لطفاً «شهر / مکان» را انتخاب کنید.');
      return;
    }

    if (_selectedCategory == null) {
      _showSnack('لطفاً «دسته‌بندی شغلی» را انتخاب کنید.');
      return;
    }

    if (_skillsList.isEmpty) {
      _showSnack('لطفاً حداقل یک مهارت وارد کرده و دکمه افزودن را بزنید.');
      return;
    }

    if (_selectedDeadline == null) {
      _showSnack('لطفاً «مهلت ارسال درخواست» (تاریخ) را تعیین کنید.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final url = Uri.parse('${ApiService.baseUrl}/projects/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'required_skills': _skillsList,
          'deadline': _selectedDeadline!.toIso8601String(),
          'project_type': _selectedProjectType,
          'city': _selectedCity,
          'category': _selectedCategory,
          'target_universities': _selectedUniversities,
          'target_majors': _selectedMajors,
          'requires_interview': _requiresInterview,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true); // ثبت موفق
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فرصت شغلی با موفقیت ایجاد شد.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        final err = jsonDecode(response.body);
        _showSnack('خطا: ${err['detail'] ?? 'ثبت با خطا مواجه شد'}');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('خطا در ارتباط با سرور: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 80, vertical: 24),
        child: Container(
          width: isMobile ? double.infinity : 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر دایالوگ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_box_rounded, color: Color(0xFF1E6AFB), size: 24),
                      SizedBox(width: 8),
                      Text('تعریف فرصت شغلی جدید (کارفرما)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // فرم ورودی‌ها
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ۱. عنوان فرصت شغلی
                        const Text('عنوان فرصت شغلی / پروژه *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('مثال: توسعه‌دهنده فلاتر / کارآموز طراحی UI/UX'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'لطفاً عنوان را وارد کنید' : null,
                        ),
                        const SizedBox(height: 16),

                        // ۲. نوع همکاری و شهر
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('نوع همکاری *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedProjectType,
                                    decoration: _inputDecoration('انتخاب نوع'),
                                    items: ['پروژه', 'کارآموزی', 'امریه'].map((type) {
                                      return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12)));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedProjectType = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('شهر / مکان *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedCity,
                                    decoration: _inputDecoration('انتخاب شهر'),
                                    items: _cities.map((city) {
                                      return DropdownMenuItem(value: city, child: Text(city, style: const TextStyle(fontSize: 12)));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedCity = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ۳. دسته‌بندی شغلی
                        const Text('دسته‌بندی شغلی *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: _inputDecoration('انتخاب حوزه کاری'),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                        const SizedBox(height: 16),

                        // ۴. دانشگاه‌های مورد قبول (چند انتخابی)
                        const Text('دانشگاه‌های اولویت‌دار (اختیاری):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _allUniversities.map((u) {
                            final isSel = _selectedUniversities.contains(u);
                            return FilterChip(
                              label: Text(u, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : Colors.black87)),
                              selected: isSel,
                              selectedColor: const Color(0xFF1E6AFB),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedUniversities.add(u);
                                  } else {
                                    _selectedUniversities.remove(u);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ۵. رشته‌های مرتبط (چند انتخابی)
                        const Text('رشته‌های تحصیلی مرتبط (اختیاری):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _allMajors.map((m) {
                            final isSel = _selectedMajors.contains(m);
                            return FilterChip(
                              label: Text(m, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : Colors.black87)),
                              selected: isSel,
                              selectedColor: const Color(0xFF10B981),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedMajors.add(m);
                                  } else {
                                    _selectedMajors.remove(m);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ۶. مهلت ارسال درخواست
                        const Text('مهلت ارسال درخواست *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _selectDeadline(context),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDeadline == null
                                      ? 'انتخاب تاریخ مهلت (روی تقویم کلیک کنید)'
                                      : '${_selectedDeadline!.year}/${_selectedDeadline!.month}/${_selectedDeadline!.day}',
                                  style: TextStyle(fontSize: 12, color: _selectedDeadline == null ? Colors.grey : Colors.black87),
                                ),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF1E6AFB)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ۷. شرح وظایف
                        const Text('شرح وظایف و خروجی مورد انتظار *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: _inputDecoration('توضیحات دقیق فرصت شغلی، انتظارات و مدارک تحویلی...'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'لطفاً توضیحات را وارد کنید' : null,
                        ),
                        const SizedBox(height: 16),

                        // ۸. مهارت‌های مورد نیاز
                        const Text('مهارت‌های مورد نیاز *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skillInputController,
                                decoration: _inputDecoration('مثال: Flutter, Python, Figma'),
                                onFieldSubmitted: (_) => _addSkill(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addSkill,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E6AFB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('افزودن'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _skillsList.map((skill) {
                            return Chip(
                              label: Text(skill, style: const TextStyle(fontSize: 11)),
                              backgroundColor: const Color(0xFFE3F2FD),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => _removeSkill(skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ۹. نیازمند مصاحبه
                        SwitchListTile(
                          value: _requiresInterview,
                          activeColor: const Color(0xFF1E6AFB),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('نیازمند مصاحبه / ملاقات حضوری', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: const Text('پس از تایید اولیه، زمان ملاقات حضوری تعیین خواهد شد.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          onChanged: (val) => setState(() => _requiresInterview = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // دکمه‌های ثبت
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                        : const Text('انتشار پروژه', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E6AFB))),
    );
  }
}