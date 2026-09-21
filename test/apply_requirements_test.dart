import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/project_details_page.dart';
import 'package:pol_app/student_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Students can read any project, but can only apply once the required profile fields are filled.

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

const _project = {
  'id': 'p1',
  'title': 'توسعه اپلیکیشن موبایل',
  'description': 'پیاده‌سازی رابط کاربری و اتصال به API.',
  'required_skills': ['Flutter'],
  'deadline': '1405/08/20',
  'project_type': 'کارآموزی',
  'city': 'تهران',
  'category': 'توسعه نرم‌افزار',
  'company_name': 'شرکت نمونه',
  'match_score': 80,
  'is_applied': false,
};

const _name = 'نام و نام خانوادگی';
const _edu = 'حداقل یک سابقه تحصیلی کامل (دانشگاه، رشته و معدل)';

void main() {
  late List<String> missing;
  late int applyCalls;
  late http.Response Function() applyResponse;

  setUp(() {
    missing = [_name, _edu];
    applyCalls = 0;
    applyResponse = () => _json({'message': 'ok'});
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/me') {
        return _json({'id': 's', 'email': 's@x.ir', 'role': 'student', 'profile': {'full_name': '', 'missing_required_fields': missing}});
      }
      if (path == '/projects/p1/apply') {
        applyCalls++;
        return applyResponse();
      }
      if (path == '/projects/options') return _json({'universities': [], 'majors': [], 'skills': []});
      return http.Response('{}', 200);
    });
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ProjectDetailsPage(project: _project)));
    await tester.pumpAndSettle();
  }

  testWidgets('incomplete profile: the project is readable, applying is replaced by what is missing', (tester) async {
    await open(tester);

    expect(find.text('توسعه اپلیکیشن موبایل'), findsWidgets, reason: 'the project itself is still shown');
    expect(find.text('ارسال درخواست و رزومه (اپلای)'), findsNothing);
    expect(find.text('برای ارسال درخواست، ابتدا این موارد را در پروفایل تکمیل کنید:'), findsOneWidget);
    expect(find.text('• $_name'), findsOneWidget);
    expect(find.text('• $_edu'), findsOneWidget);
    expect(find.text('تکمیل پروفایل برای ارسال درخواست'), findsOneWidget);
    expect(applyCalls, 0);
  });

  testWidgets('completing the profile and coming back unlocks applying', (tester) async {
    await open(tester);

    await tester.tap(find.text('تکمیل پروفایل برای ارسال درخواست'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentProfilePage), findsOneWidget);

    // The student fills the profile in, then returns.
    missing = [];
    Navigator.of(tester.element(find.byType(StudentProfilePage))).pop();
    await tester.pumpAndSettle();

    expect(find.text('برای ارسال درخواست، ابتدا این موارد را در پروفایل تکمیل کنید:'), findsNothing);
    expect(find.text('ارسال درخواست و رزومه (اپلای)'), findsOneWidget);
  });

  testWidgets('a complete profile applies normally', (tester) async {
    missing = [];
    await open(tester);

    await tester.tap(find.text('ارسال درخواست و رزومه (اپلای)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last); // send inside the message dialog
    await tester.pumpAndSettle();
    expect(applyCalls, 1);
    expect(find.text('درخواست ارسال شده است'), findsOneWidget);
  });

  testWidgets('if the server still refuses, its reason is shown and the note appears', (tester) async {
    missing = [];
    await open(tester);

    // The profile changed elsewhere after this page loaded.
    const reason = 'برای ارسال درخواست ابتدا پروفایل خود را کامل کنید: $_edu';
    applyResponse = () => _json({'detail': reason}, 400);
    missing = [_edu];

    await tester.tap(find.text('ارسال درخواست و رزومه (اپلای)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(applyCalls, 1);
    expect(find.text(reason), findsOneWidget, reason: "the server's own message, not a generic error");
    expect(find.text('• $_edu'), findsOneWidget);
    expect(find.text('ارسال درخواست و رزومه (اپلای)'), findsNothing);
  });
}
