import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    } else {
      return "http://127.0.0.1:8000";
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
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("خطای ورود: $e");
      return null;
    }
  }

  // دریافت اطلاعات کامل کاربر لاگین‌شده
  static Future<Map<String, dynamic>?> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("خطا در دریافت اطلاعات کاربر: $e");
    }
    return null;
  }

  // ذخیره و به‌روزرسانی پروفایل دانشجو
  static Future<bool> saveStudentProfile({
    required String token,
    required String fullName,
    String? phone,
    String? birthDate,
    String? residence,
    String? birthPlace,
    String? university,
    String? major,
    int? entranceYear,
    required List<String> skills,
    required List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>>? educations,
    List<Map<String, dynamic>>? workExperiences,
    String? githubLink,
    String? figmaLink,
    String? resumeFile,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/student-profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "full_name": fullName,
          "phone": phone,
          "birth_date": birthDate,
          "residence": residence,
          "birth_place": birthPlace,
          "university": university,
          "major": major,
          "entrance_year": entranceYear,
          "skills": skills,
          "courses": courses,
          "educations": educations,
          "work_experiences": workExperiences,
          "github_link": (githubLink != null && githubLink.isNotEmpty) ? githubLink : null,
          "figma_link": (figmaLink != null && figmaLink.isNotEmpty) ? figmaLink : null,
          "resume_file": resumeFile,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("خطا در ذخیره پروفایل: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchAllProjects(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/projects/"),
        headers: {
          "Authorization": "Bearer $token", // ارسال توکن برای احراز هویت
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("خطا در دریافت پروژه‌ها (کد ${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("خطا در ارتباط با سرور هنگام دریافت پروژه‌ها: $e");
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
  // ثبت درخواست برای یک پروژه توسط دانشجو
  static Future<bool> applyForProject(String token, String projectId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/projects/$projectId/apply"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("خطا در ارسال درخواست پروژه: $e");
      return false;
    }
  }
}