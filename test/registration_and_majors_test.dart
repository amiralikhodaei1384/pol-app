import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/admin_dashboard_page.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/create_project_modal.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:pol_app/company_profile_page.dart';
import 'package:pol_app/login_page.dart';
import 'package:pol_app/student_profile_builder_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _bachelor = 'مهندسی کامپیوتر';
const _master = 'مهندسی کامپیوتر - نرم‌افزار';
const _associate = 'کاردانی برق';

final _options = {
  'universities': ['دانشگاه تهران'],
  'majors': [_bachelor, _master, _associate, 'سایر'],
  'majors_by_degree': {
    'کاردانی': [_associate, 'سایر'],
    'کارشناسی': [_bachelor, 'سایر'],
    'کارشناسی ارشد': [_master, 'سایر'],
    'دکتری': [_master, 'سایر'],
  },
  'degrees': ['کاردانی', 'کارشناسی', 'کارشناسی ارشد', 'دکتری'],
  'cities': ['تهران'],
  'categories': ['توسعه نرم‌افزار'],
  'skills': ['Flutter'],
  'project_types': ['کارآموزی'],
};

void main() {
  group('registration can always go back to login', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('back arrow, "وارد شوید" link and the system back button all return to login', (tester) async {
      _setSize(tester, const Size(390, 844));
      // The login/registration backgrounds animate forever, so pumpAndSettle would never return.
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await settle();

      Future<void> openRegistration() async {
        await tester.tap(find.text('ثبت‌نام کنید'));
        await settle();
        expect(find.text('ایجاد حساب جدید'), findsOneWidget);
      }

      void expectLogin() {
        expect(find.text('ایجاد حساب جدید'), findsNothing);
        expect(find.text('خوش آمدید'), findsOneWidget);
      }

      // 1. The new back arrow on the first step.
      await openRegistration();
      await tester.tap(find.byTooltip('بازگشت به صفحه ورود'));
      await settle();
      expectLogin();

      // 2. The "already a member" link.
      await openRegistration();
      await tester.ensureVisible(find.text('وارد شوید'));
      await tester.tap(find.text('وارد شوید'));
      await settle();
      expectLogin();

      // 3. System back: first steps back through the form, then returns to login.
      await openRegistration();
      await tester.enterText(find.byType(TextFormField).first, 'student@uni.ac.ir');
      await tester.tap(find.text('مرحله بعد'));
      await settle();
      expect(find.text('ایجاد حساب جدید'), findsNothing, reason: 'moved on to the password step');
      expect(find.text('وارد شوید'), findsOneWidget, reason: 'the login link is on every step now');

      await tester.binding.handlePopRoute();
      await settle();
      expect(find.text('ایجاد حساب جدید'), findsOneWidget, reason: 'back goes to the previous step first');

      await tester.binding.handlePopRoute();
      await settle();
      expectLogin();
    });
  });

  group('majors follow the chosen degree', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      ApiService.client = MockClient((req) async {
        if (req.url.path == '/projects/options') return _json(_options);
        return _json({'id': 's', 'email': 's@x.ir', 'role': 'student'});
      });
    });

    testWidgets('education form: searchable university/major, majors limited to the degree', (tester) async {
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(const MaterialApp(home: StudentProfileBuilderPage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('افزودن مقطع تحصیلی جدید'));
      await tester.tap(find.text('افزودن مقطع تحصیلی جدید'));
      await tester.pumpAndSettle();

      Finder majorField(String degree) => find.widgetWithText(TextField, 'جستجو و انتخاب رشته مقطع $degree');
      Finder inList(String text) => find.descendant(of: find.byType(ListView), matching: find.text(text));

      // University is searchable too.
      await tester.tap(find.widgetWithText(TextField, 'جستجو و انتخاب دانشگاه از لیست'));
      await tester.pumpAndSettle();
      await tester.tap(inList('دانشگاه تهران'));
      await tester.pumpAndSettle();

      // Default degree is کارشناسی: only bachelor majors, and typing filters them.
      await tester.tap(majorField('کارشناسی'));
      await tester.pumpAndSettle();
      expect(inList(_bachelor), findsOneWidget);
      expect(inList(_master), findsNothing, reason: 'master majors must not show for کارشناسی');
      expect(inList(_associate), findsNothing);
      await tester.enterText(majorField('کارشناسی'), 'کامپیوتر');
      await tester.pumpAndSettle();
      await tester.tap(inList(_bachelor));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, _bachelor), findsOneWidget, reason: 'picked');

      // Reopening a filled field shows the whole list again, not just the current pick.
      await tester.tap(find.widgetWithText(TextField, _bachelor));
      await tester.pumpAndSettle();
      expect(inList('سایر'), findsOneWidget);
      await tester.tap(find.text('افزودن مقطع تحصیلی جدید').last); // inside the form: closes the list, not the form
      await tester.pumpAndSettle();

      // Switch to کارشناسی ارشد: the bachelor pick is cleared and only master majors are offered.
      // The degree dropdown is the only dropdown left in the education form.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'کارشناسی').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('کارشناسی ارشد').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, _bachelor), findsNothing, reason: 'a bachelor major is not valid for a master degree');

      await tester.tap(majorField('کارشناسی ارشد'));
      await tester.pumpAndSettle();
      expect(inList(_master), findsOneWidget);
      expect(inList(_bachelor), findsNothing, reason: 'bachelor majors must not show for کارشناسی ارشد');

      // Typed text that isn't an option is refused on save.
      await tester.enterText(majorField('کارشناسی ارشد'), 'رشته ساختگی');
      await tester.pumpAndSettle();
      await tester.tap(find.text('افزودن مقطع تحصیلی جدید').last); // inside the form: closes the list, not the form
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ثبت سابقه تحصیلی'));
      await tester.tap(find.text('ثبت سابقه تحصیلی'));
      await tester.pump();
      expect(find.text('لطفاً دانشگاه و رشته تحصیلی را از لیست انتخاب کنید.'), findsOneWidget);
    });

    testWidgets('project form offers bachelor majors only and refuses typed majors', (tester) async {
      _setSize(tester, const Size(900, 2000));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CreateProjectModal())));
      await tester.pumpAndSettle();

      final majors = find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('جستجوی رشته کارشناسی'));
      Finder inList(String text) => find.descendant(of: find.byType(ListView), matching: find.text(text));
      expect(find.text('رشته‌های تحصیلی مرتبط در مقطع کارشناسی (اختیاری)'), findsOneWidget);

      await tester.tap(majors);
      await tester.pumpAndSettle();
      expect(inList(_bachelor), findsOneWidget);
      expect(inList(_master), findsNothing, reason: 'graduate majors are for display only');
      expect(inList(_associate), findsNothing);

      // Choosing a target degree doesn't change the list: matching is always at bachelor level.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('به ترتیب اولویت')));
      await tester.pumpAndSettle();
      await tester.tap(inList('دکتری'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(majors);
      await tester.pumpAndSettle();
      expect(inList(_bachelor), findsOneWidget);
      expect(inList(_master), findsNothing);

      // Free text isn't accepted as a major.
      await tester.enterText(majors, 'رشته ساختگی');
      await tester.pumpAndSettle();
      expect(find.text('موردی یافت نشد.'), findsOneWidget, reason: 'no "press Enter to add" hint for majors');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      // Order of the add buttons: universities, degrees, majors, skills.
      await tester.tap(find.widgetWithText(ElevatedButton, 'افزودن').at(2));
      await tester.pumpAndSettle();
      expect(find.text('لطفاً یکی از گزینه‌های فهرست را انتخاب کنید.'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'رشته ساختگی'), findsNothing);
    });
  });

  testWidgets('admin: majors filter by degree and their degrees can be edited', (tester) async {
    _setSize(tester, const Size(1440, 900));
    final patches = <Map<String, dynamic>>[];
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_admin': true});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/me') return _json({'id': 'a', 'email': 'admin@pol.ir', 'role': 'admin'});
      if (path == '/admin/stats') return http.Response('{}', 500);
      if (path == '/admin/options') {
        return _json({
          'universities': [],
          'majors': [
            {'id': 'm1', 'name': _bachelor, 'degrees': ['کارشناسی']},
            {'id': 'm2', 'name': _master, 'degrees': ['کارشناسی ارشد', 'دکتری']},
            {'id': 'm3', 'name': 'سایر', 'degrees': []},
          ],
          'degrees': [
            for (final d in ['دکتری', 'کاردانی', 'کارشناسی', 'کارشناسی ارشد']) {'id': d, 'name': d}
          ],
          'cities': [], 'categories': [], 'skills': [], 'project_types': [],
        });
      }
      if (req.method == 'PATCH' && path.startsWith('/admin/options/majors/')) {
        patches.add({'path': path, ...jsonDecode(req.body) as Map<String, dynamic>});
        return _json({'id': 'm1', 'name': _bachelor, 'degrees': ['کارشناسی', 'کاردانی']});
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('اطلاعات پایه')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رشته‌ها (۳)'));
    await tester.pumpAndSettle();

    // Each major shows its degrees; "سایر" has none, so it's offered everywhere.
    expect(find.text('کارشناسی ارشد، دکتری'), findsOneWidget);
    expect(find.text('همه مقاطع'), findsOneWidget);

    // Degree filter, in study order, with counts that include the every-degree major.
    expect(find.text('کارشناسی (۲)'), findsOneWidget);
    await tester.tap(find.text('کارشناسی ارشد (۲)'));
    await tester.pumpAndSettle();
    expect(find.text(_bachelor), findsNothing);
    expect(find.text(_master), findsOneWidget);
    await tester.tap(find.text('همه (۳)'));
    await tester.pumpAndSettle();

    // Edit a major's degrees.
    await tester.tap(find.text(_bachelor));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'کاردانی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(patches, [
      {'path': '/admin/options/majors/m1', 'degrees': ['کاردانی', 'کارشناسی'], 'bachelor_major': null}
    ]);
    expect(find.text('کاردانی، کارشناسی'), findsOneWidget, reason: 'chip updates without reloading');
  });

  group('sign-up wizards can be left and finished later', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      ApiService.client = MockClient((req) async {
        switch (req.url.path) {
          case '/projects/options':
            return _json(_options);
          case '/auth/me':
            return _json({'id': 's', 'email': 's@x.ir', 'role': 'student', 'company': {'name': 'شرکت', 'address': 'تهران'}});
          case '/projects/notifications/counts':
            return _json({'unread_notifications': 0, 'unread_chats': 0});
        }
        return http.Response('[]', 200);
      });
    });
    tearDown(() => NotificationPoller.instance.stop());

    testWidgets('student wizard: «بعداً تکمیل می‌کنم» and the back button lead to the dashboard', (tester) async {
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(const MaterialApp(home: StudentProfileBuilderPage()));
      await tester.pumpAndSettle();

      // Back on the first step asks first; "continue" keeps you in the wizard.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('ادامه در زمان دیگر؟'), findsOneWidget);
      await tester.tap(find.text('ادامه تکمیل'));
      await tester.pumpAndSettle();
      expect(find.text('تکمیل پروفایل دانشجویی'), findsOneWidget);

      await tester.tap(find.text('بعداً تکمیل می‌کنم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفتن به داشبورد'));
      // The dashboard keeps animating (spinners, polling), so pump a fixed time instead of settling.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('تکمیل پروفایل دانشجویی'), findsNothing);
      expect(find.byType(DashboardPage), findsOneWidget);
      NotificationPoller.instance.stop(); // the dashboard's 3s poller must not outlive the test
    });

    testWidgets('company wizard: «بعداً تکمیل می‌کنم» leads to the company dashboard', (tester) async {
      _setSize(tester, const Size(1200, 900));
      await tester.pumpWidget(const MaterialApp(home: CompanyProfilePage(isWizard: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('بعداً تکمیل می‌کنم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفتن به داشبورد'));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CompanyProfilePage), findsNothing);
      expect(tester.widget<DashboardPage>(find.byType(DashboardPage)).isCompany, isTrue);
      NotificationPoller.instance.stop();
    });
  });

  testWidgets('admin: a graduate major needs its bachelor major, which is sent and shown', (tester) async {
    _setSize(tester, const Size(1440, 900));
    final posts = <Map<String, dynamic>>[];
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_admin': true});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/me') return _json({'id': 'a', 'email': 'admin@pol.ir', 'role': 'admin'});
      if (path == '/admin/stats') return http.Response('{}', 500);
      if (req.method == 'POST' && path == '/admin/options/majors') {
        posts.add(jsonDecode(req.body) as Map<String, dynamic>);
        return _json({'id': 'm9', 'name': 'x', 'degrees': ['دکتری'], 'bachelor_major': _bachelor});
      }
      if (path == '/admin/options') {
        return _json({
          'universities': [],
          'majors': [
            {'id': 'm1', 'name': _bachelor, 'degrees': ['کارشناسی'], 'bachelor_major': null},
            {'id': 'm2', 'name': _master, 'degrees': ['کارشناسی ارشد', 'دکتری'], 'bachelor_major': _bachelor},
          ],
          'degrees': [
            for (final d in ['دکتری', 'کاردانی', 'کارشناسی', 'کارشناسی ارشد']) {'id': d, 'name': d}
          ],
          'cities': [], 'categories': [], 'skills': [], 'project_types': [],
        });
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('اطلاعات پایه')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رشته‌ها (۲)'));
    await tester.pumpAndSettle();

    // The link is shown on the chip.
    expect(find.text('کارشناسی ارشد، دکتری  ·  کارشناسی: $_bachelor'), findsOneWidget);

    // Picking only دکتری asks for the bachelor major, and adding without it is refused.
    expect(find.text('رشته کارشناسی مرتبط (برای امتیازدهی) *'), findsNothing);
    final degreeChips = find.ancestor(of: find.text('دکتری'), matching: find.byType(InkWell));
    await tester.tap(degreeChips.first);
    await tester.pumpAndSettle();
    expect(find.text('رشته کارشناسی مرتبط (برای امتیازدهی) *'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'مهندسی کامپیوتر - بازی‌سازی');
    await tester.tap(find.widgetWithText(ElevatedButton, 'افزودن'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
    expect(find.text('رشته کارشناسی مرتبط را انتخاب کنید.'), findsOneWidget);

    // Only bachelor majors are offered as the link.
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'انتخاب رشته کارشناسی'));
    await tester.pumpAndSettle();
    expect(find.text(_master), findsOneWidget, reason: 'only the chip, not a menu item');
    await tester.tap(find.text(_bachelor).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'افزودن'));
    await tester.pumpAndSettle();
    expect(posts, [
      {'name': 'مهندسی کامپیوتر - بازی‌سازی', 'degrees': ['دکتری'], 'bachelor_major': _bachelor}
    ]);
  });
}
