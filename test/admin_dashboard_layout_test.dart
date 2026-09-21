import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/admin_dashboard_page.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Renders every admin section at phone, tablet and desktop sizes with realistic data.
// Any RenderFlex overflow is reported by Flutter as an exception, which fails the test.

final _stats = {
  'users': {'total': 1284, 'students': 1102, 'companies': 176, 'admins': 6, 'blocked': 12, 'new_this_week': 48},
  'companies': 151,
  'projects': {'total': 342, 'active': 298},
  'applications': {'total': 5210, 'applied': 3100, 'shortlisted': 1200, 'accepted': 610, 'rejected': 300},
  'chats': {'threads': 870, 'messages': 15420},
  'signups_last_7_days': [
    for (var i = 0; i < 7; i++) {'date_fa': '1405/06/${24 + i}', 'count': [3, 0, 12, 7, 25, 1, 9][i]}
  ],
  'top_projects': [
    for (var i = 0; i < 5; i++)
      {'id': 'p$i', 'title': 'توسعه اپلیکیشن موبایل با فلاتر و اتصال به سرویس‌های ابری شماره $i', 'company_name': 'شرکت فناوری اطلاعات نوآوران پارس', 'applications': 120 - i * 10}
  ],
  'latest_users': [
    for (var i = 0; i < 5; i++)
      {'id': 'u$i', 'email': 'very.long.student.email.address.$i@university-of-tehran.ac.ir', 'role': i.isEven ? 'student' : 'company_rep', 'name': 'علی محمدی زاده اصفهانی $i', 'created_at_fa': '1405/06/30'}
  ],
};

final _users = [
  for (var i = 0; i < 6; i++)
    {
      'id': 'u$i',
      'email': 'very.long.email.address.for.testing.$i@some-company-domain.co.ir',
      'role': ['student', 'company_rep', 'admin'][i % 3],
      'name': 'نام بسیار طولانی کاربر برای آزمایش چیدمان $i',
      'detail': 'دانشگاه صنعتی امیرکبیر (پلی‌تکنیک تهران) • مهندسی کامپیوتر',
      'activity_count': 14,
      'is_active': i != 1,
      'created_at_fa': '1405/06/30',
    }
];

final _projects = [
  for (var i = 0; i < 4; i++)
    {
      'id': 'p$i',
      'title': 'پیاده‌سازی داشبورد مدیریتی و گزارش‌گیری پیشرفته برای سامانه $i',
      'company_name': 'شرکت فناوری اطلاعات نوآوران پارس',
      'project_type': 'کارآموزی',
      'city': 'تهران',
      'category': 'توسعه نرم‌افزار',
      'deadline': '1405/08/20',
      'applications': 37,
      'is_active': i != 2,
      'created_at_fa': '1405/06/12',
    }
];

final _options = {
  for (final k in ['universities', 'majors', 'degrees', 'cities', 'categories', 'skills', 'project_types'])
    k: [for (var i = 0; i < 12; i++) {'id': '$k$i', 'name': 'گزینه آزمایشی طولانی $i'}]
};

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_admin': true});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/me') return _json({'id': 'a', 'email': 'admin@pol.ir', 'role': 'admin'});
      if (path == '/admin/stats') return _json(_stats);
      if (path == '/admin/users') return _json(_users);
      if (path == '/admin/projects') return _json(_projects);
      if (path == '/admin/options') return _json(_options);
      return http.Response('not found', 404);
    });
  });

  // name -> (screen size, text scale)
  const sizes = {
    'small phone 320x640': (Size(320, 640), 1.0),
    'phone 390x844': (Size(390, 844), 1.0),
    'phone 390x844 with 130% text': (Size(390, 844), 1.3),
    'tablet 768x1024': (Size(768, 1024), 1.0),
    'narrow desktop 960x700': (Size(960, 700), 1.0),
    'desktop 1440x900': (Size(1440, 900), 1.0),
  };
  // sidebar label -> text that only appears once that section is open
  const sections = {
    'نمای کلی': 'پنل مدیریت پل 🛡️',
    'مدیریت کاربران': 'جستجو بر اساس نام، ایمیل یا نام شرکت...',
    'مدیریت پروژه‌ها': 'جستجو بر اساس عنوان پروژه یا نام شرکت...',
    'اطلاعات پایه': 'افزودن',
    'ارسال اعلان همگانی': 'ارسال اعلان به کاربران',
  };

  for (final entry in sizes.entries) {
    testWidgets('admin panel has no overflow at ${entry.key}', (tester) async {
      final (size, textScale) = entry.value;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        // Phones with enlarged system text must not overflow either.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AdminDashboardPage(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('پنل مدیریت پل 🛡️'), findsOneWidget);

      final usesDrawer = size.width < 900;
      for (final section in sections.entries) {
        if (usesDrawer) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(section.key)));
        await tester.pumpAndSettle();
        expect(find.text(section.value), findsOneWidget, reason: '${section.key} did not open');
      }
      // The panel polls for unread chats; stop it so no timer outlives the test.
      NotificationPoller.instance.stop();
    });
  }
}
