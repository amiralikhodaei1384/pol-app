import 'package:flutter/material.dart';

/// Asks whether to leave a sign-up wizard for the dashboard and finish it later.
/// Returns true when the user chose to leave.
Future<bool> confirmLeaveWizard(BuildContext context, {required String message}) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ادامه در زمان دیگر؟', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        content: Text(message, style: const TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ادامه تکمیل', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E6AFB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('رفتن به داشبورد', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
  return leave == true;
}
