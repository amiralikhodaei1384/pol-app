import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:pol_app/student_profile_builder_page.dart';
import 'package:pol_app/widgets/search_picker_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// ---------------------------------------------------------------- search field

Widget _pickerApp({required TextEditingController controller, required List<String> selected, required void Function(String) onSelected, void Function(String)? onSubmitted}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchPickerField(
                      key: const Key('picker'),
                      controller: controller,
                      options: const ['Flutter', 'Dart', 'Python', 'React', 'JavaScript', 'SQL', 'Figma', 'Docker'],
                      exclude: selected,
                      onSelected: onSelected,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {}, child: const Text('افزودن')),
                ],
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- dashboard

List<Map<String, dynamic>> _applications() => [
      for (var i = 0; i < 8; i++)
        {
          'id': 'app$i',
          'project_id': 'project$i',
          'title': 'پروژه شماره $i',
          'company_name': 'شرکت نمونه',
          'city': 'تهران',
          'project_type': 'کارآموزی',
          'status': i == 6 ? 'shortlisted' : 'applied',
          'status_fa': i == 6 ? 'دعوت به مصاحبه حضوری' : 'در انتظار بررسی',
          'created_at': '1405/06/2$i',
          'interview_date': i == 6 ? '1405/07/01 - ساعت 10' : null,
          'interview_address': i == 6 ? 'تهران' : null,
          'interview_note': null,
          'decision_note': null,
          'decided_at_fa': '',
        }
    ];

void main() {
  group('SearchPickerField', () {
    testWidgets('opens on focus, matches the field width, shows 4 rows and scrolls for the rest', (tester) async {
      _setSize(tester, const Size(390, 844));
      final controller = TextEditingController();
      await tester.pumpWidget(_pickerApp(controller: controller, selected: const [], onSelected: (_) {}));

      expect(find.text('Flutter'), findsNothing, reason: 'closed until focused');
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Opens with no typing at all.
      expect(find.text('Flutter'), findsOneWidget);

      final field = tester.getRect(find.byType(TextField));
      final list = tester.getRect(find.byType(ListView));
      expect(list.width, moreOrLessEquals(field.width - 2, epsilon: 0.5), reason: 'list (inside a 1px border) is as wide as the field, not the row');
      expect(list.left, moreOrLessEquals(field.left + 1, epsilon: 0.5));
      expect(list.top, greaterThan(field.bottom), reason: 'opens under the field');
      expect(list.height, moreOrLessEquals(4 * 42 - 2, epsilon: 0.5), reason: 'exactly 4 rows visible');

      // Rows past the 4th are reached by scrolling.
      expect(find.text('Docker'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Docker'), findsOneWidget);
    });

    testWidgets('typing filters, chosen items are hidden, picking keeps the list open for the next one', (tester) async {
      _setSize(tester, const Size(390, 844));
      final controller = TextEditingController();
      final selected = <String>[];
      late StateSetter rebuild;
      await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return _pickerApp(
          controller: controller,
          selected: List.of(selected),
          onSelected: (v) => rebuild(() {
            selected.add(v);
            controller.clear();
          }),
        );
      }));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'script');
      await tester.pumpAndSettle();
      expect(find.text('JavaScript'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);

      await tester.tap(find.text('JavaScript'));
      await tester.pumpAndSettle();
      expect(selected, ['JavaScript']);
      // Still open with the full list minus the chosen item.
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('JavaScript')), findsNothing);
    });

    testWidgets('tapping the field itself toggles the list; typing brings it back', (tester) async {
      _setSize(tester, const Size(390, 844));
      final controller = TextEditingController();
      await tester.pumpWidget(_pickerApp(controller: controller, selected: const [], onSelected: (_) {}));
      final field = find.byType(TextField);

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget, reason: 'first tap opens it');

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing, reason: 'tapping the field again closes it');
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue, reason: 'the field keeps focus so you can keep typing');

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget, reason: 'and tapping once more opens it again');

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      await tester.enterText(field, 'py');
      await tester.pumpAndSettle();
      expect(find.text('Python'), findsOneWidget, reason: 'typing reopens the list with matches');

      // A tap on the field's clear button must not be mistaken for a tap that closes the list.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
    });

    testWidgets('no match: Enter still adds free text, and tapping elsewhere closes the list', (tester) async {
      _setSize(tester, const Size(390, 844));
      final controller = TextEditingController();
      String? submitted;
      await tester.pumpWidget(_pickerApp(controller: controller, selected: const [], onSelected: (_) {}, onSubmitted: (v) => submitted = v));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Rust');
      await tester.pumpAndSettle();
      expect(find.textContaining('موردی یافت نشد'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, 'Rust');

      await tester.tapAt(const Offset(200, 700));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('notification jump to the application', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      ApiService.client = MockClient((req) async {
        switch (req.url.path) {
          case '/projects/my-applications':
            return _json(_applications());
          case '/auth/me':
            return _json({'id': 's', 'email': 's@x.ir', 'role': 'student', 'profile': {'full_name': 'علی', 'completion_percentage': 60}});
          case '/projects/notifications/counts':
            return _json({'unread_notifications': 0, 'unread_chats': 0});
          case '/projects/':
            return _json([]);
        }
        return http.Response('[]', 200);
      });
    });

    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      testWidgets('scrolls to and highlights the invited application (${size.width.toInt()}px)', (tester) async {
        _setSize(tester, size);
        await tester.pumpWidget(const MaterialApp(home: DashboardPage(focusProjectId: 'project6')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final card = find.ancestor(of: find.text('پروژه شماره 6'), matching: find.byType(AnimatedContainer)).first;
        final rect = tester.getRect(card);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: 'the invited application is on screen');

        final highlighted = tester.widget<AnimatedContainer>(card).decoration as BoxDecoration;
        expect((highlighted.border as Border).top.color, const Color(0xFFF59E0B));

        // The highlight fades after a few seconds.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        final after = tester.widget<AnimatedContainer>(card).decoration as BoxDecoration;
        expect((after.border as Border).top.color, isNot(const Color(0xFFF59E0B)));

        NotificationPoller.instance.stop();
      });
    }
  });

  testWidgets('profile builder: full-width "next" on step 1, equal halves after; GPA is required', (tester) async {
    _setSize(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    ApiService.client = MockClient((req) async {
      if (req.url.path == '/projects/options') {
        return _json({
          'universities': ['دانشگاه تهران'],
          'majors': ['مهندسی کامپیوتر'],
          'degrees': ['کارشناسی'],
          'skills': <String>[],
        });
      }
      return _json({'id': 's', 'email': 's@x.ir', 'role': 'student'});
    });
    await tester.pumpWidget(const MaterialApp(home: StudentProfileBuilderPage()));
    await tester.pumpAndSettle();

    // Step 1: no "previous", so "next" fills the row (390 - 2*16 padding).
    expect(find.text('گام قبلی'), findsNothing);
    expect(tester.getRect(find.widgetWithText(ElevatedButton, 'گام بعدی')).width, moreOrLessEquals(390 - 32, epsilon: 1));

    await tester.enterText(find.widgetWithText(TextField, 'مثال: علی'), 'علی');
    await tester.enterText(find.widgetWithText(TextField, 'مثال: محمدی'), 'محمدی');

    // Education dialog: university and major chosen, GPA left empty -> refused.
    await tester.ensureVisible(find.text('افزودن مقطع تحصیلی جدید'));
    await tester.tap(find.text('افزودن مقطع تحصیلی جدید'));
    await tester.pumpAndSettle();
    for (final pick in [('جستجو و انتخاب دانشگاه از لیست', 'دانشگاه تهران'), ('جستجو و انتخاب رشته مقطع کارشناسی', 'مهندسی کامپیوتر')]) {
      await tester.tap(find.widgetWithText(TextField, pick.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text(pick.$2)));
      await tester.pumpAndSettle();
    }
    expect(find.text('معدل *'), findsOneWidget);
    await tester.tap(find.text('ثبت سابقه تحصیلی'));
    await tester.pump();
    expect(find.text('لطفاً معدل را وارد کنید.'), findsOneWidget);

    // Not a number -> refused too (this used to slip through).
    // Snackbars queue, so clear the first message before checking the next one.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'مثال: 18.5'), '..');
    await tester.tap(find.text('ثبت سابقه تحصیلی'));
    await tester.pumpAndSettle();
    expect(find.text('معدل باید عددی بین ۰ تا ۲۰ باشد.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'مثال: 18.5'), '18.5');
    await tester.tap(find.text('ثبت سابقه تحصیلی'));
    await tester.pumpAndSettle();
    expect(find.text('افزودن مقطع تحصیلی جدید'), findsWidgets, reason: 'back on the page with the dialog closed');
    expect(find.text('ثبت سابقه تحصیلی'), findsNothing);

    // Step 2: both buttons appear and share the row equally.
    // (Clear the earlier error message first; it sits on top of the bottom buttons.)
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'گام بعدی'));
    await tester.pumpAndSettle();
    final previous = tester.getRect(find.widgetWithText(OutlinedButton, 'گام قبلی'));
    final next = tester.getRect(find.widgetWithText(ElevatedButton, 'گام بعدی'));
    expect(next.width, moreOrLessEquals((390 - 32 - 12) / 2, epsilon: 1));
    expect(previous.width, moreOrLessEquals(next.width, epsilon: 0.5));
    expect(previous.height, moreOrLessEquals(next.height, epsilon: 0.5));

    // Back to step 1: full width again.
    await tester.tap(find.widgetWithText(OutlinedButton, 'گام قبلی'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.widgetWithText(ElevatedButton, 'گام بعدی')).width, moreOrLessEquals(390 - 32, epsilon: 1));
  });
}
