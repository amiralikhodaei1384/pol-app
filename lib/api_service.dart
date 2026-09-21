import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pol_app/session_guard.dart';

/// HTTP client for the backend REST API.
class ApiService {
  /// Shared client for every request; logs the user out if the server reports their account as blocked.
  static http.Client client = SessionGuardClient();

  /// Backend address for the current platform (Android emulator uses 10.0.2.2).
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
      final res = await client.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "role": isCompany ? "company_rep" : "student",
          "company_name": companyName,
          "national_id": nationalId,
          "company_address": companyAddress,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("خطا در ثبت‌نام: $e");
      return false;
    }
  }
  static Future<bool> saveCompanyProfile({
    required String token,
    String? name,
    String? about,
    String? website,
    String? address,
  }) async {
    try {
      final res = await client.post(
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
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await client.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": email, "password": password}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      // Blocked account: pass the server's message through instead of "wrong password".
      if (res.statusCode == 403) {
        return {'error': _detailOf(res) ?? 'حساب کاربری شما مسدود شده است.'};
      }
    } catch (e) {
      print("خطا در ورود: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getMe(String token) async {
    try {
      final res = await client.get(
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

  static Future<Map<String, dynamic>?> fetchOptions() async {
    try {
      final res = await client.get(Uri.parse("$baseUrl/projects/options"));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در دریافت گزینه‌های دیتابیس: $e");
    }
    return null;
  }

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
      final res = await client.post(
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

      var streamedResponse = await client.send(request);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['file_url'] ?? data['file_name'];
      } else {
        print("خطای آپلود رزومه (کد ${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("خطا در ارسال فایل: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchAllProjects(String token) async {
    try {
      final res = await client.get(
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

  static Future<List<dynamic>> fetchFilteredProjects({
    required String token,
    String? projectType,
    List<String>? cities,
    List<String>? categories,
    List<String>? relatedMajors,
    List<String>? universities,
    String? searchQuery,
  }) async {
    try {
      var uri = Uri.parse("$baseUrl/projects/");
      Map<String, String> queryParams = {};

      if (projectType != null && projectType != "همه") queryParams['project_type'] = projectType;

      if (cities != null && cities.isNotEmpty && !cities.contains("همه")) {
        queryParams['cities'] = cities.join(",");
      }
      if (categories != null && categories.isNotEmpty && !categories.contains("همه")) {
        queryParams['categories'] = categories.join(",");
      }
      if (relatedMajors != null && relatedMajors.isNotEmpty && !relatedMajors.contains("همه")) {
        queryParams['majors'] = relatedMajors.join(",");
      }
      if (universities != null && universities.isNotEmpty && !universities.contains("همه")) {
        queryParams['universities'] = universities.join(",");
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      uri = uri.replace(queryParameters: queryParams);

      final res = await client.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("خطا در جستجوی پروژه‌ها: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchRecommendedProjects(String token) async {
    try {
      final res = await client.get(
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

  static Future<List<dynamic>> fetchMyProjects(String token) async {
    try {
      final res = await client.get(
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

  static Future<List<dynamic>> fetchMyApplications(String token) async {
    try {
      final res = await client.get(
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

  static Future<bool> applyForProject(String token, String projectId, {String? message}) async {
    try {
      final res = await client.post(
        Uri.parse("$baseUrl/projects/$projectId/apply"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": message}),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print("خطا در ثبت درخواست: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchCompanyApplications(String token, {String? projectId}) async {
    try {
      var uri = Uri.parse("$baseUrl/projects/company-applications");
      if (projectId != null && projectId.isNotEmpty) {
        uri = uri.replace(queryParameters: {'project_id': projectId});
      }

      final res = await client.get(
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

  static Future<bool> scheduleInterview(String token, String appId, String date, String address, String note) async {
    try {
      final res = await client.post(
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

  static Future<String?> startChat(String token, String appId) async {
    try {
      final res = await client.post(
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

  static Future<List<dynamic>> fetchChatThreads(String token) async {
    try {
      final res = await client.get(
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

  static Future<List<dynamic>> fetchMessages(String token, String threadId) async {
    try {
      final res = await client.get(
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

  static Future<bool> sendMessage(
      String token,
      String threadId,
      String text, {
        String? fileUrl,
        String? fileType,
        String? fileName,
      }) async {
    try {
      final res = await client.post(
        Uri.parse("$baseUrl/projects/chat/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "thread_id": threadId,
          "text": text,
          "file_url": fileUrl,
          "file_type": fileType,
          "file_name": fileName,
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در ارسال پیام: $e");
      return false;
    }
  }
  static Future<Map<String, dynamic>> fetchNotificationCounts(String token) async {
    try {
      final res = await client.get(
        Uri.parse("$baseUrl/projects/notifications/counts"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {}
    return {"unread_notifications": 0, "unread_chats": 0};
  }

  static Future<List<dynamic>> fetchNotifications(String token) async {
    try {
      final res = await client.get(
        Uri.parse("$baseUrl/projects/notifications/"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {}
    return [];
  }
  static Future<Map<String, dynamic>?> uploadChatFile({
    required String token,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      var req = http.MultipartRequest('POST', Uri.parse("$baseUrl/projects/chat/upload-file"));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

      var streamedResponse = await client.send(req);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("خطا در آپلود فایل چت: $e");
    }
    return null;
  }

  static Future<bool> deleteProject(String token, String projectId) async {
    try {
      final res = await client.delete(
        Uri.parse("$baseUrl/projects/$projectId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در حذف پروژه: $e");
      return false;
    }
  }

  static Future<bool> deleteChatMessage(String token, String messageId) async {
    try {
      final res = await client.delete(
        Uri.parse("$baseUrl/projects/chat/messages/$messageId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در حذف پیام چت: $e");
      return false;
    }
  }

  static Future<bool> deleteNotification(String token, String notificationId) async {
    try {
      final res = await client.delete(
        Uri.parse("$baseUrl/projects/notifications/$notificationId"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در حذف اعلان: $e");
      return false;
    }
  }
  static Future<bool> editChatMessage(String token, String messageId, String newText) async {
    try {
      final res = await client.put(
        Uri.parse("$baseUrl/projects/chat/messages/$messageId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "message_id": messageId,
          "text": newText,
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      print("خطا در ویرایش پیام: $e");
      return false;
    }
  }

  // ---------------- پنل مدیریت ----------------

  /// Error message FastAPI put in the response body, if any.
  static String? _detailOf(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] is String) return body['detail'];
    } catch (_) {}
    return null;
  }

  static Map<String, String> _auth(String token, {bool json = false}) => {
        "Authorization": "Bearer $token",
        if (json) "Content-Type": "application/json",
      };

  static Future<Map<String, dynamic>?> fetchAdminStats(String token) async {
    try {
      final res = await client.get(Uri.parse("$baseUrl/admin/stats"), headers: _auth(token)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      print("خطا در دریافت آمار: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchAdminUsers(String token, {String role = 'all', String search = ''}) async {
    try {
      final uri = Uri.parse("$baseUrl/admin/users").replace(queryParameters: {
        'role': role,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      });
      final res = await client.get(uri, headers: _auth(token)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      print("خطا در دریافت کاربران: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchAdminProjects(String token, {String status = 'all', String search = ''}) async {
    try {
      final uri = Uri.parse("$baseUrl/admin/projects").replace(queryParameters: {
        'status': status,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      });
      final res = await client.get(uri, headers: _auth(token)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      print("خطا در دریافت پروژه‌ها: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchAdminOptions(String token) async {
    try {
      final res = await client.get(Uri.parse("$baseUrl/admin/options"), headers: _auth(token)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      print("خطا در دریافت اطلاعات پایه: $e");
    }
    return null;
  }

  /// Write calls return null on success, or the error message to show.
  static Future<String?> _write(Future<http.Response> Function() send) async {
    try {
      final res = await send().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return null;
      return _detailOf(res) ?? 'عملیات با خطا مواجه شد (${res.statusCode}).';
    } catch (e) {
      return 'ارتباط با سرور برقرار نشد.';
    }
  }

  /// Employer accepts or rejects an application; [decision] is 'accepted' or 'rejected'.
  static Future<String?> decideApplication(String token, String appId, String decision, {String? note}) => _write(() => client.post(
        Uri.parse("$baseUrl/projects/applications/$appId/decision"),
        headers: _auth(token, json: true),
        body: jsonEncode({"decision": decision, "note": note}),
      ));

  static Future<String?> setUserActive(String token, String userId, bool isActive) => _write(() => client.patch(
        Uri.parse("$baseUrl/admin/users/$userId/status"),
        headers: _auth(token, json: true),
        body: jsonEncode({"is_active": isActive}),
      ));

  static Future<String?> deleteUserAsAdmin(String token, String userId) =>
      _write(() => client.delete(Uri.parse("$baseUrl/admin/users/$userId"), headers: _auth(token)));

  static Future<String?> setProjectActive(String token, String projectId, bool isActive) => _write(() => client.patch(
        Uri.parse("$baseUrl/admin/projects/$projectId/status"),
        headers: _auth(token, json: true),
        body: jsonEncode({"is_active": isActive}),
      ));

  static Future<String?> deleteProjectAsAdmin(String token, String projectId) =>
      _write(() => client.delete(Uri.parse("$baseUrl/admin/projects/$projectId"), headers: _auth(token)));

  static Future<String?> addOption(String token, String kind, String name) => _write(() => client.post(
        Uri.parse("$baseUrl/admin/options/$kind"),
        headers: _auth(token, json: true),
        body: jsonEncode({"name": name}),
      ));

  static Future<String?> deleteOption(String token, String kind, String optionId) =>
      _write(() => client.delete(Uri.parse("$baseUrl/admin/options/$kind/$optionId"), headers: _auth(token)));

  /// Returns how many users received it, or throws the server's message.
  static Future<int> sendBroadcast(String token, {required String title, required String message, required String audience}) async {
    http.Response res;
    try {
      res = await client.post(
        Uri.parse("$baseUrl/admin/broadcast"),
        headers: _auth(token, json: true),
        body: jsonEncode({"title": title, "message": message, "audience": audience}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw 'ارتباط با سرور برقرار نشد.';
    }
    if (res.statusCode == 200) return (jsonDecode(utf8.decode(res.bodyBytes))['recipients'] as num).toInt();
    throw _detailOf(res) ?? 'ارسال اعلان ناموفق بود.';
  }
}
