import 'package:flutter/material.dart';

// تابع فراخوانی مدال انتخاب تاریخ شمسی
Future<String?> showShamsiDatePicker({
  required BuildContext context,
  String title = 'انتخاب تاریخ شمسی',
  int startYear = 1340,
  int endYear = 1410,
  int? initialYear,
  int initialMonth = 1,
  int initialDay = 1,
  bool includeTime = false,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _ShamsiDatePickerDialog(
      title: title,
      startYear: startYear,
      endYear: endYear,
      initialYear: initialYear ?? 1405,
      initialMonth: initialMonth,
      initialDay: initialDay,
      includeTime: includeTime,
    ),
  );
}

class _ShamsiDatePickerDialog extends StatefulWidget {
  final String title;
  final int startYear;
  final int endYear;
  final int initialYear;
  final int initialMonth;
  final int initialDay;
  final bool includeTime;

  const _ShamsiDatePickerDialog({
    required this.title,
    required this.startYear,
    required this.endYear,
    required this.initialYear,
    required this.initialMonth,
    required this.initialDay,
    required this.includeTime,
  });

  @override
  State<_ShamsiDatePickerDialog> createState() => _ShamsiDatePickerDialogState();
}

class _ShamsiDatePickerDialogState extends State<_ShamsiDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  String _selectedTime = '10:00';

  final List<String> _shamsiMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  final List<String> _times = [
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00'
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _selectedDay = widget.initialDay;
  }

  int get _maxDays {
    if (_selectedMonth <= 6) return 31;
    if (_selectedMonth <= 11) return 30;
    return 29; // اسفند
  }

  @override
  Widget build(BuildContext context) {
    final yearList = List.generate(widget.endYear - widget.startYear + 1, (i) => widget.startYear + i);
    if (_selectedDay > _maxDays) _selectedDay = _maxDays;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // هدر دایالوگ
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Color(0xFF1E6AFB), size: 24),
                  const SizedBox(width: 8),
                  Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
              const Divider(height: 24),

              // نمایش تاریخ انتخابی بزرگ در باکس سبز
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Center(
                  child: Text(
                    '$_selectedYear / ${_selectedMonth.toString().padLeft(2, '0')} / ${_selectedDay.toString().padLeft(2, '0')}' +
                        (widget.includeTime ? '  -  ساعت $_selectedTime' : ''),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // منوهای انتخابی سال، ماه، روز
              Row(
                children: [
                  // سال
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سال', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: yearList.contains(_selectedYear) ? _selectedYear : yearList.first,
                          isExpanded: true,
                          decoration: _inputDec(),
                          items: yearList.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _selectedYear = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ماه
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ماه', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          isExpanded: true,
                          decoration: _inputDec(),
                          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_shamsiMonths[i], style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (v) => setState(() => _selectedMonth = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // روز
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('روز', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _selectedDay <= _maxDays ? _selectedDay : 1,
                          isExpanded: true,
                          decoration: _inputDec(),
                          items: List.generate(_maxDays, (i) => DropdownMenuItem(value: i + 1, child: Text((i + 1).toString(), style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _selectedDay = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // انتخاب ساعت در صورت نیاز
              if (widget.includeTime) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ساعت', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedTime,
                      isExpanded: true,
                      decoration: _inputDec(),
                      items: _times.map((t) => DropdownMenuItem(value: t, child: Text('ساعت $t', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => _selectedTime = v!),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // دکمه‌های اکشن
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final formattedMonth = _selectedMonth.toString().padLeft(2, '0');
                      final formattedDay = _selectedDay.toString().padLeft(2, '0');
                      var result = '$_selectedYear/$formattedMonth/$formattedDay';
                      if (widget.includeTime) {
                        result += ' - ساعت $_selectedTime';
                      }
                      Navigator.pop(context, result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('تأیید تاریخ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}