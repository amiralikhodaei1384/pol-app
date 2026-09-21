import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/shamsi_date_picker_dialog.dart';

/// Dialog for employers to post a new project.
class CreateProjectModal extends StatefulWidget {
  const CreateProjectModal({super.key});

  @override
  State<CreateProjectModal> createState() => _CreateProjectModalState();
}

class _CreateProjectModalState extends State<CreateProjectModal> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _skillInputController = TextEditingController();
  final TextEditingController _univInputController = TextEditingController();
  final TextEditingController _majorInputController = TextEditingController();
  final TextEditingController _degreeInputController = TextEditingController();

  String? _selectedProjectType;
  String? _selectedCity;
  String? _selectedCategory;

  List<String> _selectedUniversities = [];
  List<String> _selectedMajors = [];
  List<String> _selectedDegrees = [];
  final List<String> _skillsList = [];

  // Filled from /projects/options.
  List<String> _projectTypes = [];
  List<String> _cities = [];
  List<String> _categories = [];
  List<String> _allUniversities = [];
  List<String> _allMajors = [];
  List<String> _allDegrees = [];
  List<String> _allSkillsOptions = [];

  String? _selectedDeadline;
  bool _isLoading = false;

  double _univWeight = 0.25;
  double _majorWeight = 0.25;
  double _skillsWeight = 0.25;
  double _degreeWeight = 0.10;
  double _profileWeight = 0.15;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final opts = await ApiService.fetchOptions();
    if (opts != null && mounted) {
      setState(() {
        if (opts['project_types'] != null) _projectTypes = (opts['project_types'] as List).cast<String>();
        if (opts['cities'] != null) _cities = (opts['cities'] as List).cast<String>();
        if (opts['categories'] != null) _categories = (opts['categories'] as List).cast<String>();
        if (opts['universities'] != null) _allUniversities = (opts['universities'] as List).cast<String>();
        if (opts['majors'] != null) _allMajors = (opts['majors'] as List).cast<String>();
        if (opts['degrees'] != null) _allDegrees = (opts['degrees'] as List).cast<String>();
        if (opts['skills'] != null) _allSkillsOptions = (opts['skills'] as List).cast<String>();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillInputController.dispose();
    _univInputController.dispose();
    _majorInputController.dispose();
    _degreeInputController.dispose();
    super.dispose();
  }

  void _addSkill([String? customSkill]) {
    final text = customSkill ?? _skillInputController.text.trim();
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

  void _addUniversity([String? customUni]) {
    final text = customUni ?? _univInputController.text.trim();
    if (text.isNotEmpty && !_selectedUniversities.contains(text)) {
      setState(() {
        _selectedUniversities.add(text);
        _univInputController.clear();
      });
    }
  }

  void _removeUniversity(String university) {
    setState(() {
      _selectedUniversities.remove(university);
    });
  }

  void _addMajor([String? customMajor]) {
    final text = customMajor ?? _majorInputController.text.trim();
    if (text.isNotEmpty && !_selectedMajors.contains(text)) {
      setState(() {
        _selectedMajors.add(text);
        _majorInputController.clear();
      });
    }
  }

  void _removeMajor(String major) {
    setState(() {
      _selectedMajors.remove(major);
    });
  }

  void _addDegree([String? customDegree]) {
    final text = customDegree ?? _degreeInputController.text.trim();
    if (text.isNotEmpty && !_selectedDegrees.contains(text)) {
      setState(() {
        _selectedDegrees.add(text);
        _degreeInputController.clear();
      });
    }
  }

  void _removeDegree(String degree) {
    setState(() {
      _selectedDegrees.remove(degree);
    });
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final date = await showShamsiDatePicker(
      context: context,
      title: 'انتخاب مهلت ارسال درخواست',
      startYear: 1405,
      endYear: 1410,
      initialYear: 1405,
      initialMonth: 4,
      initialDay: 1,
    );
    if (date != null) {
      setState(() {
        _selectedDeadline = date;
      });
    }
  }

  /// Validates the form and sends the project to the backend.
  Future<void> _submitProject() async {
    if (_skillInputController.text.trim().isNotEmpty) _addSkill();
    if (_univInputController.text.trim().isNotEmpty) _addUniversity();
    if (_majorInputController.text.trim().isNotEmpty) _addMajor();

    if (!_formKey.currentState!.validate()) return;

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
      _showSnack('لطفاً حداقل یک مهارت انتخاب کرده یا اضافه کنید.');
      return;
    }

    if (_selectedDeadline == null || _selectedDeadline!.isEmpty) {
      _showSnack('لطفاً «مهلت ارسال درخواست» (تاریخ) را تعیین کنید.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final url = Uri.parse('${ApiService.baseUrl}/projects/');

      final response = await ApiService.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'required_skills': _skillsList,
          'deadline': _selectedDeadline,
          'project_type': _selectedProjectType,
          'city': _selectedCity,
          'category': _selectedCategory,
          'target_universities': _selectedUniversities,
          'target_majors': _selectedMajors,
          'target_degrees': _selectedDegrees,
          'weights': {
            'university_weight': _univWeight,
            'major_weight': _majorWeight,
            'skills_weight': _skillsWeight,
            'degree_weight': _degreeWeight,
            'profile_weight': _profileWeight,
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فرصت شغلی با موفقیت ایجاد شد.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        _handleBackendError(response);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('خطا در ارتباط با سرور. لطفاً اتصال اینترنت خود را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBackendError(http.Response response) {
    String errorMessage = 'خطایی در ثبت اطلاعات رخ داد.';
    try {
      final err = jsonDecode(response.body);
      if (response.statusCode == 422 && err['detail'] is List) {
        final List details = err['detail'];
        List<String> parsedErrors = [];
        for (var item in details) {
          if (item is Map) {
            final loc = item['loc'] as List?;
            final field = loc != null && loc.isNotEmpty ? loc.last.toString() : '';

            if (field == 'title') {
              parsedErrors.add('• عنوان پروژه بسیار کوتاه است (حداقل ۳ کاراکتر).');
            } else if (field == 'description') {
              parsedErrors.add('• شرح وظایف بسیار کوتاه است (حداقل ۱۰ کاراکتر).');
            } else {
              parsedErrors.add('• ${item['msg'] ?? 'اطلاعات وارد شده معتبر نیست.'}');
            }
          }
        }
        if (parsedErrors.isNotEmpty) errorMessage = parsedErrors.join('\n');
      } else if (err['detail'] is String) {
        errorMessage = err['detail'];
      }
    } catch (_) {}
    _showSnack(errorMessage);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  /// Search field with live suggestions and removable chips.
  Widget _buildAutocompleteSearchInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> allOptions,
    required List<String> selectedList,
    required Function(String) onAdd,
    required Function(String) onRemove,
    required Color chipColor,
  }) {
    final query = controller.text.trim().toLowerCase();
    final suggestions = query.isEmpty
        ? []
        : allOptions
        .where((opt) => opt.toLowerCase().contains(query) && !selectedList.contains(opt))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    onAdd(val.trim());
                    controller.clear();
                    setState(() {});
                  }
                },
                style: const TextStyle(fontSize: 12),
                decoration: _inputDecoration(hint).copyWith(
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                  controller.clear();
                  setState(() {});
                }
              },
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

        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E6AFB)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(suggestion, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                  trailing: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                  onTap: () {
                    setState(() {
                      onAdd(suggestion);
                      controller.clear();
                    });
                  },
                );
              },
            ),
          ),
        ],

        if (selectedList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedList.map((item) {
              return Chip(
                label: Text(item, style: const TextStyle(fontSize: 11)),
                backgroundColor: chipColor.withOpacity(0.15),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => onRemove(item),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildWeightSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            Text('${(value * 100).round()}٪', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          activeColor: const Color(0xFF1E6AFB),
          onChanged: onChanged,
        ),
      ],
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

              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('عنوان فرصت شغلی / پروژه * (حداقل ۳ کاراکتر)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('مثال: توسعه‌دهنده فلاتر / کارآموز طراحی UI/UX'),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'لطفاً عنوان پروژه را وارد کنید';
                            }
                            if (val.trim().length < 3) {
                              return 'عنوان پروژه باید حداقل ۳ کاراکتر باشد';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

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
                                    items: _projectTypes.map((type) {
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

                        _buildAutocompleteSearchInput(
                          label: 'دانشگاه‌های اولویت‌دار (اختیاری)',
                          hint: 'جستجوی دانشگاه (مثال: تهران، شریف)...',
                          controller: _univInputController,
                          allOptions: _allUniversities,
                          selectedList: _selectedUniversities,
                          onAdd: _addUniversity,
                          onRemove: _removeUniversity,
                          chipColor: const Color(0xFF1E6AFB),
                        ),
                        const SizedBox(height: 16),

                        _buildAutocompleteSearchInput(
                          label: 'رشته‌های تحصیلی مرتبط (اختیاری)',
                          hint: 'جستجوی رشته (مثال: کامپیوتر، برق)...',
                          controller: _majorInputController,
                          allOptions: _allMajors,
                          selectedList: _selectedMajors,
                          onAdd: _addMajor,
                          onRemove: _removeMajor,
                          chipColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 16),

                        _buildAutocompleteSearchInput(
                          label: 'مقاطع تحصیلی مورد نظر (اختیاری)',
                          hint: 'به ترتیب اولویت (مثال: کارشناسی برای کارآموزی)...',
                          controller: _degreeInputController,
                          allOptions: _allDegrees,
                          selectedList: _selectedDegrees,
                          onAdd: _addDegree,
                          onRemove: _removeDegree,
                          chipColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 16),

                        _buildAutocompleteSearchInput(
                          label: 'مهارت‌های مورد نیاز *',
                          hint: 'جستجوی مهارت (مثال: Flutter, Python)...',
                          controller: _skillInputController,
                          allOptions: _allSkillsOptions,
                          selectedList: _skillsList,
                          onAdd: _addSkill,
                          onRemove: _removeSkill,
                          chipColor: const Color(0xFF1E6AFB),
                        ),
                        const SizedBox(height: 16),

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
                                  _selectedDeadline ?? 'انتخاب تاریخ مهلت (روی تقویم کلیک کنید)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedDeadline == null ? Colors.grey : Colors.black87,
                                    fontWeight: _selectedDeadline == null ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF1E6AFB)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('شرح وظایف و خروجی مورد انتظار * (حداقل ۱۰ کاراکتر)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: _inputDecoration('توضیحات دقیق فرصت شغلی، انتظارات و مدارک تحویلی...'),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'لطفاً شرح وظایف را وارد کنید';
                            }
                            if (val.trim().length < 10) {
                              return 'شرح وظایف باید حداقل ۱۰ کاراکتر باشد';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        ExpansionTile(
                          title: const Text('وزن‌دهی تطبیق هوشمند (اختیاری)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
                          subtitle: const Text('تنظیم میزان اهمیت دانشگاه، رشته، مهارت‌ها، مقطع و تکمیل پروفایل در رتبه‌بندی', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          childrenPadding: const EdgeInsets.all(8),
                          children: [
                            _buildWeightSlider('میزان اهمیت دانشگاه', _univWeight, (val) => setState(() => _univWeight = val)),
                            _buildWeightSlider('میزان اهمیت رشته تحصیلی', _majorWeight, (val) => setState(() => _majorWeight = val)),
                            _buildWeightSlider('میزان اهمیت مهارت‌ها', _skillsWeight, (val) => setState(() => _skillsWeight = val)),
                            _buildWeightSlider('میزان اهمیت مقطع تحصیلی', _degreeWeight, (val) => setState(() => _degreeWeight = val)),
                            _buildWeightSlider('میزان اهمیت تکمیل پروفایل', _profileWeight, (val) => setState(() => _profileWeight = val)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
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