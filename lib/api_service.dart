import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // اگر روی شبیه‌ساز اندروید تست می‌کنید از http://10.0.2.2:8000 استفاده کنید
  // اگر روی ویندوز یا وب تست می‌کنید http://127.0.0.1:8000 درست است
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<bool> register({
    required String email,
    required String password,
    required bool isCompany,
    String? companyName,
    String? nationalId,
    String? companyAddress,
  }) async {
    try {
      final bodyData = {
        "email": email,
        "password": password,
        "role": isCompany ? "company_rep" : "student",
        "company_name": isCompany ? companyName : null,
        "national_id": isCompany ? nationalId : null,
        "company_address": isCompany ? companyAddress : null,
        // اصلاح ارور: فرستادن نام شرکت یا عنوان به جای null
        "full_name": isCompany ? (companyName ?? "نماینده شرکت") : "دانشجوی جدید",
      };

      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("ثبت‌نام با موفقیت انجام شد.");
        return true;
      } else {
        // پرینت دقیق ارور بک‌اند در کنسول VS Code / Android Studio
        print("خطا در ثبت‌نام (کد ${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      print("خطای اتصال یا شبکه: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // بازگرداندن پاسخ کامل شامل access_token و نقش کاربر
      } else {
        print("خطا در ورود: ${response.body}");
        return null;
      }
    } catch (e) {
      print("خطای شبکه در ورود: $e");
      return null;
    }
  }
}