import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

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

  // Form State
  String _selectedProjectType = 'پروژه'; // پروژه / کارآموزی / امریه
  final List<String> _skillsList = [];
  DateTime? _selectedDeadline;
  bool _requiresInterview = true;
  bool _isLoading = false;

  // Matching Weights (بخش ۵.۲ سند UX)
  double _univWeight = 0.25;
  double _majorWeight = 0.25;
  double _skillsWeight = 0.30;
  double _coursesWeight = 0.20;

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
    if (!_formKey.currentState!.validate()) return;

    if (_skillsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً حداقل یک مهارت اضافه کنید.')),
      );
      return;
    }

    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً مهلت پیشنهادی را مشخص کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // آدرس API بک‌اند خود را در اینجا وارد کنید
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
          'requires_interview': _requiresInterview,
          'weights': {
            'university_weight': _univWeight,
            'major_weight': _majorWeight,
            'skills_weight': _skillsWeight,
            'courses_weight': _coursesWeight,
          }
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pop(context, true); // موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پروژه با موفقیت ایجاد شد.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${err['detail'] ?? 'خطایی رخ داد'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارتباط با سرور: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      Text('تعریف پروژه یا کارآموزی جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        // ۱. عنوان پروژه
                        const Text('عنوان پروژه *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('مثال: توسعه رابط کاربری اپلیکیشن موبایل با فلاتر'),
                          validator: (val) => val == null || val.isEmpty ? 'لطفاً عنوان پروژه را وارد کنید' : null,
                        ),
                        const SizedBox(height: 16),

                        // ۲. نوع همکاری و مهلت پیشنهادی
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
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedProjectType = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('مهلت پیشنهادی *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                                ? 'انتخاب تاریخ'
                                                : '${_selectedDeadline!.year}/${_selectedDeadline!.month}/${_selectedDeadline!.day}',
                                            style: TextStyle(fontSize: 12, color: _selectedDeadline == null ? Colors.grey : Colors.black87),
                                          ),
                                          const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ۳. شرح وظایف و خروجی مورد انتظار
                        const Text('شرح وظایف و خروجی مورد انتظار *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: _inputDecoration('توضیحات دقیق پروژه، انتظارات و مدارک تحویلی...'),
                          validator: (val) => val == null || val.isEmpty ? 'لطفاً توضیحات را وارد کنید' : null,
                        ),
                        const SizedBox(height: 16),

                        // ۴. مهارت‌های مورد نیاز
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

                        // ۵. گزینه‌های تکمیلی
                        SwitchListTile(
                          value: _requiresInterview,
                          activeColor: const Color(0xFF1E6AFB),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('نیازمند مصاحبه / ملاقات حضوری', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: const Text('پس از تایید رزومه، زمان ملاقات حضوری تعیین خواهد شد.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          onChanged: (val) => setState(() => _requiresInterview = val),
                        ),
                        const SizedBox(height: 12),

                        // ۶. آکاردئون تنظیم وزن‌دهی تطبیق (بخش ۵.۲ و ۳ سند UX)
                        ExpansionTile(
                          title: const Text('وزن‌دهی تطبیق هوشمند (اختیاری)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
                          subtitle: const Text('تنظیم میزان اهمیت هر معیار در رتبه‌بندی دانشجویان', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          childrenPadding: const EdgeInsets.all(8),
                          children: [
                            _buildWeightSlider('میزان اهمیت دانشگاه', _univWeight, (val) => setState(() => _univWeight = val)),
                            _buildWeightSlider('میزان اهمیت رشته تحصیلی', _majorWeight, (val) => setState(() => _majorWeight = val)),
                            _buildWeightSlider('میزان اهمیت مهارت‌ها', _skillsWeight, (val) => setState(() => _skillsWeight = val)),
                            _buildWeightSlider('میزان اهمیت نمرات دروس مرتبط', _coursesWeight, (val) => setState(() => _coursesWeight = val)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // دکمه‌های اکشن
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
}