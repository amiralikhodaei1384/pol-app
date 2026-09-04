import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // تشخیص هوشمند آدرس سرور متناسب با محیط اجرا (وب، شبیه‌ساز اندروید، دسکتاپ)
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    } else {
      return "http://127.0.0.1:8000";
    }
  }

  // ۱. ثبت‌نام کاربر جدید
  // ۱. ثبت‌نام کاربر جدید (دانشجو یا شرکت)
  static Future<bool> register({
    required String email,
    required String password,
    required bool isCompany,
    String? companyName,
    String? nationalId,
    String? companyAddress, // <--- پارامتر آدرس شرکت اضافه شد
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "role": isCompany ? "company_rep" : "student",
          "company_name": companyName,
          "national_id": nationalId,
          "company_address": companyAddress, // <--- ارسال آدرس شرکت به بک‌اند
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("خطا در ثبت‌نام: $e");
      return false;
    }
  }
  // ویرایش اطلاعات شرکت توسط کارفرما
  static Future<bool> saveCompanyProfile({
    required String token,
    String? name,
    String? about,
    String? website,
    String? address,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/company-profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "about": about,
          "website": website,
          "address": address,
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در ذخیره پروفایل شرکت: $e");
      return false;
    }
  }
  // ۲. ورود (Login) و دریافت توکن
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": email, "password": password}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در ورود: $e");
    }
    return null;
  }

  // ۳. دریافت مشخصات کامل کاربر جاری
  static Future<Map<String, dynamic>?> getMe(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت اطلاعات کاربر: $e");
    }
    return null;
  }

  // ۴. دریافت گزینه‌های استاندارد دیتابیس (دانشگاه‌ها، رشته‌ها، شهرها، دسته‌بندی‌ها)
  static Future<Map<String, dynamic>?> fetchOptions() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/projects/options"));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت گزینه‌های دیتابیس: $e");
    }
    return null;
  }

  // ۵. ذخیره و به‌روزرسانی پروفایل دانشجو
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
      final res = await http.post(
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

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("خطا در ذخیره پروفایل: $e");
      return false;
    }
  }

  // ۶. آپلود بایت‌های فایل رزومه PDF به سرور
  static Future<String?> uploadResume({
    required String token,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/auth/upload-resume"),
      );
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['file_name'];
      } else {
        print("خطای آپلود رزومه: ${response.body}");
      }
    } catch (e) {
      print("خطا در ارسال بایت‌های فایل: $e");
    }
    return null;
  }

  // ۷. دریافت همه پروژه‌ها
  static Future<List<dynamic>> fetchAllProjects(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت پروژه‌ها: $e");
    }
    return [];
  }

  // ۸. دریافت پروژه‌ها با فیلترهای چندگانه (شامل فیلتر دانشگاه - اصلاح شد)
  static Future<List<dynamic>> fetchFilteredProjects({
    required String token,
    String? projectType,
    String? city,
    String? category,
    String? relatedMajor,
    String? university, // <--- پارامتر دانشگاه اضافه شد
    String? searchQuery,
  }) async {
    try {
      var uri = Uri.parse("$baseUrl/projects/");
      Map<String, String> queryParams = {};

      if (projectType != null && projectType != "همه") queryParams['project_type'] = projectType;
      if (city != null && city != "همه") queryParams['city'] = city;
      if (category != null && category != "همه") queryParams['category'] = category;
      if (relatedMajor != null && relatedMajor != "همه") queryParams['related_major'] = relatedMajor;
      if (university != null && university != "همه") queryParams['university'] = university; // <--- ارسال پارامتر دانشگاه
      if (searchQuery != null && searchQuery.isNotEmpty) queryParams['search'] = searchQuery;

      uri = uri.replace(queryParameters: queryParams);

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("خطا در فیلتر پروژه‌ها (کد ${res.statusCode}): ${res.body}");
      }
    } catch (e) {
      print("خطا در جستجوی پروژه‌ها: $e");
    }
    return [];
  }

  // ۹. دریافت پروژه‌های پیشنهادی هوشمند برای دانشجو
  static Future<List<dynamic>> fetchRecommendedProjects(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/recommended"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت پروژه‌های پیشنهادی: $e");
    }
    return [];
  }

  // ۱۰. دریافت پروژه‌های ثبت‌شده توسط شرکت (برای کارفرما)
  static Future<List<dynamic>> fetchMyProjects(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/my-projects"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت پروژه‌های من: $e");
    }
    return [];
  }

  // ۱۱. دریافت لیست درخواست‌های ارسال‌شده دانشجو (پیگیری اپلای‌ها)
  static Future<List<dynamic>> fetchMyApplications(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/my-applications"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت درخواست‌های من: $e");
    }
    return [];
  }

  // ۱۲. ارسال درخواست برای پروژه توسط دانشجو
  static Future<bool> applyForProject(String token, String projectId) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/projects/$projectId/apply"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("خطا در ثبت درخواست: $e");
      return false;
    }
  }

  // ۱۳. دریافت بورد درخواست‌ها و رزومه‌های دریافت‌شده برای کارفرما
  // دریافت بورد رزومه‌ها و متقاضیان (با امکان دریافت آیدی پروژه خاص)
  static Future<List<dynamic>> fetchCompanyApplications(String token, {String? projectId}) async {
    try {
      var uri = Uri.parse("$baseUrl/projects/company-applications");
      if (projectId != null && projectId.isNotEmpty) {
        uri = uri.replace(queryParameters: {'project_id': projectId});
      }

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت رزومه‌های متقاضیان: $e");
    }
    return [];
  }

  // ۱۴. ثبت دعوت به مصاحبه حضوری توسط کارفرما
  static Future<bool> scheduleInterview(String token, String appId, String date, String address, String note) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/projects/applications/$appId/schedule-interview"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "interview_date": date,
          "interview_address": address,
          "interview_note": note,
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در ثبت مصاحبه: $e");
      return false;
    }
  }

  // ۱۵. شروع چت اختصاصی توسط کارفرما
  static Future<String?> startChat(String token, String appId) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/projects/chat/start?app_id=$appId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body)['thread_id'];
      }
    } catch (e) {
      print("خطا در ایجاد چت: $e");
    }
    return null;
  }

  // ۱۶. دریافت لیست تمام گفتگوهای چت
  static Future<List<dynamic>> fetchChatThreads(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/chat/threads"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت لیست چت‌ها: $e");
    }
    return [];
  }

  // ۱۷. دریافت پیام‌های یک چت خاص
  static Future<List<dynamic>> fetchMessages(String token, String threadId) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/chat/messages/$threadId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت پیام‌ها: $e");
    }
    return [];
  }

  // ۱۸. ارسال پیام در چت
  static Future<bool> sendMessage(String token, String threadId, String text) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/projects/chat/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"thread_id": threadId, "text": text}),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در ارسال پیام: $e");
      return false;
    }
  }
}