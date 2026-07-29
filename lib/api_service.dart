import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // تشخیص هوشمند آدرس سرور متناسب با محیط اجرا (وب، اندروید، ویندوز)
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000"; // اجرا روی وب/کروم
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000"; // اجرا روی شبیه‌ساز اندروید
    } else {
      return "http://127.0.0.1:8000"; // اجرا روی ویندوز یا بقیه
    }
  }

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
        "full_name": isCompany ? (companyName ?? "نماینده شرکت") : "دانشجوی جدید",
      };

      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("خطا در ثبت‌نام: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": email, "password": password}),
      ).timeout(const Duration(seconds: 5)); // تعیین تایم‌اوت ۵ ثانیه‌ای جهت جلوگیری از معطلی

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("خطای پاسخ سرور: ${response.body}");
        return null;
      }
    } catch (e) {
      print("خطای ارتباط با سرور: $e");
      return null;
    }
  }

  static Future<List<dynamic>> fetchAllProjects() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/projects/")).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("خطا در دریافت پروژه‌ها: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchMyProjects(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/projects/my-projects"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("خطا در دریافت پروژه‌های من: $e");
    }
    return [];
  }
}