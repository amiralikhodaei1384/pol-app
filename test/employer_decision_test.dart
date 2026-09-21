import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/employer_applications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The employer's applicant list: accept/reject flow, status filter, and no overflow from phone to desktop.

Map<String, dynamic> _app(int i, String status) => {
      'application_id': 'a$i',
      'project_title': 'توسعه اپلیکیشن موبایل با فلاتر و اتصال به سرویس‌های ابری',
      'student_name': 'نام بسیار طولانی دانشجو برای آزمایش چیدمان $i',
      'student_phone': '09120000000',
      'student_university': 'دانشگاه صنعتی امیرکبیر',
      'student_major': 'مهندسی کامپیوتر',
      'student_skills': ['Flutter', 'Dart'],
      'student_educations': [],
      'student_work_experiences': [],
      'student_courses': [],
      'student_resume': null,
      'student_message': 'سلام، علاقه‌مند به همکاری هستم.',
      'match_score': 80 - i,
      'status': status,
      'interview_date': status == 'shortlisted' ? '1405/07/01 - ساعت 10' : null,
      'interview_address': status == 'shortlisted' ? 'تهران، خیابان آزادی' : null,
      'interview_note': null,
      'decision_note': status == 'accepted' ? 'از شنبه شروع کنید' : null,
      'decided_at_fa': status == 'accepted' || status == 'rejected' ? '1405/06/30' : '',
      'student_accepted_count': i == 0 ? 2 : 0,
      'created_at': '2026-09-2${i}T10:00:00',
      'created_at_fa': '1405/06/2$i',
      'has_chat': false,
      'chat_thread_id': null,
    };

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void main() {
  late List<Map<String, dynamic>> decisions;

  setUp(() {
    decisions = [];
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_company': true});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/me') return _json({'id': 'c', 'email': 'c@x.ir', 'role': 'company_rep', 'company': {'address': 'تهران'}});
      if (path == '/projects/company-applications') {
        return _json([_app(0, 'applied'), _app(1, 'shortlisted'), _app(2, 'accepted'), _app(3, 'rejected')]);
      }
      if (path.endsWith('/decision')) {
        decisions.add({'path': path, ...jsonDecode(req.body) as Map<String, dynamic>});
        return _json({'message': 'ok'});
      }
      return http.Response('not found', 404);
    });
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: EmployerApplicationsPage()));
    await tester.pumpAndSettle();
  }

  const sizes = {'small phone': Size(320, 640), 'phone': Size(390, 844), 'desktop': Size(1440, 900)};

  for (final entry in sizes.entries) {
    testWidgets('no overflow with every status, expanded cards and dialogs (${entry.key})', (tester) async {
      await pumpAt(tester, entry.value);

      // Every status filter, then back to all.
      for (final label in ['در انتظار بررسی (1)', 'دعوت به مصاحبه (1)', 'پذیرفته‌شده (1)', 'ردشده (1)', 'همه (4)']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      // Expand each card to render its details panel.
      for (final name in [for (var i = 0; i < 4; i++) 'نام بسیار طولانی دانشجو برای آزمایش چیدمان $i']) {
        await tester.scrollUntilVisible(find.text(name), 200, scrollable: find.byType(Scrollable).last);
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      // Back to the top: the list only builds visible cards, and the pending one is first.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 5000));
      await tester.pumpAndSettle();

      // Both dialogs open without overflow.
      for (final button in ['پذیرش', 'رد درخواست']) {
        await tester.ensureVisible(find.text(button).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(button).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('انصراف'));
        await tester.pumpAndSettle();
      }
      expect(decisions, isEmpty, reason: 'cancelling must not send anything');
    });
  }

  testWidgets('accepting sends the decision with the note and updates the card', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.ensureVisible(find.text('در انتظار بررسی (1)'));
    await tester.tap(find.text('در انتظار بررسی (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پذیرش'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  لطفاً شنبه مراجعه کنید ');
    await tester.tap(find.text('پذیرش و اطلاع به دانشجو'));
    await tester.pumpAndSettle();

    expect(decisions, [
      {'path': '/projects/applications/a0/decision', 'decision': 'accepted', 'note': 'لطفاً شنبه مراجعه کنید'}
    ]);
    // Counts move from "pending" to "accepted" without reloading.
    expect(find.text('در انتظار بررسی (0)'), findsOneWidget);
    expect(find.text('پذیرفته‌شده (2)'), findsOneWidget);
    expect(find.text('درخواست پذیرفته شد و به دانشجو اطلاع داده شد.'), findsOneWidget);
  });

  testWidgets('a decided application offers to change the decision instead of accept/reject', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.ensureVisible(find.text('پذیرفته‌شده (1)'));
    await tester.tap(find.text('پذیرفته‌شده (1)'));
    await tester.pumpAndSettle();
    expect(find.text('پذیرش'), findsNothing);
    expect(find.text('دعوت به مصاحبه حضوری'), findsNothing);
    expect(find.text('تغییر به ردشده'), findsOneWidget);

    await tester.tap(find.text('تغییر به ردشده'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'رد درخواست'));
    await tester.pumpAndSettle();

    expect(decisions.single['decision'], 'rejected');
    expect(find.text('ردشده (2)'), findsOneWidget);
  });
}
