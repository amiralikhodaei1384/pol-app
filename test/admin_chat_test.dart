import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pol_app/admin_dashboard_page.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/chat_page.dart';
import 'package:pol_app/chat_threads_page.dart';
import 'package:pol_app/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Admin panel: chat with a specific student/company, send them a direct message, and the messages entry.

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

final _users = [
  {'id': 'u1', 'email': 'ali@uni.ac.ir', 'role': 'student', 'name': 'علی محمدی', 'detail': '', 'activity_count': 2, 'is_active': true, 'created_at_fa': '1405/06/30'},
  {'id': 'u2', 'email': 'hr@alpha.ir', 'role': 'company_rep', 'name': 'شرکت آلفا', 'detail': '', 'activity_count': 1, 'is_active': true, 'created_at_fa': '1405/06/30'},
  {'id': 'u3', 'email': 'admin@pol.ir', 'role': 'admin', 'name': 'مدیر سامانه', 'detail': '', 'activity_count': 0, 'is_active': true, 'created_at_fa': '1405/06/30'},
];

void main() {
  late List<String> requests;
  late Map<String, dynamic>? lastMessage;
  late http.Response Function() threadsResponse;

  setUp(() {
    requests = [];
    lastMessage = null;
    threadsResponse = () => _json([
          {'thread_id': 't-u1', 'title': 'گفتگو با علی محمدی', 'other_party': 'علی محمدی', 'is_admin_chat': true}
        ]);
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_admin': true});
    ApiService.client = MockClient((req) async {
      final path = req.url.path;
      requests.add('${req.method} $path');
      if (path == '/auth/me') return _json({'id': 'a', 'email': 'admin@pol.ir', 'role': 'admin'});
      if (path == '/admin/stats') return http.Response('{}', 500);
      if (path == '/admin/users') return _json(_users);
      if (path == '/projects/notifications/counts') return _json({'unread_notifications': 3, 'unread_chats': 3});
      if (path == '/admin/users/u1/chat') return _json({'thread_id': 't-u1', 'other_party': 'علی محمدی'});
      if (path == '/admin/users/u2/message') {
        lastMessage = jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
        return _json({'thread_id': 't-u2', 'other_party': 'شرکت آلفا', 'message': 'ok'});
      }
      if (path.startsWith('/projects/chat/messages/')) return _json([]);
      if (path == '/projects/chat/threads') return threadsResponse();
      return http.Response('[]', 200);
    });
  });

  Future<void> openUsers(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();
    if (size.width < 900) {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('مدیریت کاربران')));
    await tester.pumpAndSettle();
  }

  testWidgets('students and companies get chat + message buttons, admins do not', (tester) async {
    await openUsers(tester, const Size(1440, 900));
    expect(find.text('گفتگو'), findsNWidgets(2));
    expect(find.text('ارسال پیام'), findsNWidgets(2));
    NotificationPoller.instance.stop();
  });

  testWidgets('«گفتگو» opens the chat with that student', (tester) async {
    await openUsers(tester, const Size(1440, 900));
    await tester.tap(find.text('گفتگو').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(requests, contains('POST /admin/users/u1/chat'));
    expect(find.byType(ChatPage), findsOneWidget);
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).threadId, 't-u1');

    // Leave the chat so its 2s polling timer is disposed before the test ends.
    Navigator.of(tester.element(find.byType(ChatPage))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    NotificationPoller.instance.stop();
  });

  testWidgets('«ارسال پیام» posts into the chat with that company and offers to open it', (tester) async {
    await openUsers(tester, const Size(1440, 900));
    await tester.tap(find.text('ارسال پیام').last);
    await tester.pumpAndSettle();
    expect(find.text('ارسال پیام به «شرکت آلفا»'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'ارسال'));
    await tester.pumpAndSettle();
    expect(find.text('متن پیام را وارد کنید.'), findsOneWidget);
    expect(lastMessage, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'متن پیام...'), '  لطفاً اطلاعات شرکت را کامل کنید. ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'ارسال'));
    await tester.pumpAndSettle();

    expect(lastMessage, {'text': 'لطفاً اطلاعات شرکت را کامل کنید.'});
    expect(find.text('پیام در گفتگو با «شرکت آلفا» ارسال شد.'), findsOneWidget);

    // The snackbar opens that very conversation.
    await tester.tap(find.text('مشاهده گفتگو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).threadId, 't-u2');
    Navigator.of(tester.element(find.byType(ChatPage))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    NotificationPoller.instance.stop();
  });

  Future<void> openThreads(WidgetTester tester, {required bool admin}) async {
    SharedPreferences.setMockInitialValues({'access_token': 't', 'is_admin': admin});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ChatThreadsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('no conversations: the admin is told how to start one', (tester) async {
    threadsResponse = () => _json([]);
    await openThreads(tester, admin: true);
    expect(find.textContaining('در «مدیریت کاربران» روی «گفتگو» یا «ارسال پیام»'), findsOneWidget);
    expect(find.textContaining('اقدام کارفرما'), findsNothing, reason: 'the old "only employers start chats" text is gone');
    await tester.pumpWidget(const SizedBox()); // dispose the page's polling timer
  });

  testWidgets('no conversations: students learn an employer or the admin can start one', (tester) async {
    threadsResponse = () => _json([]);
    await openThreads(tester, admin: false);
    expect(find.textContaining('کارفرما یا مدیر سامانه'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a server error is shown as an error with retry, not as "no conversations"', (tester) async {
    threadsResponse = () => http.Response('boom', 500);
    await openThreads(tester, admin: true);
    expect(find.text('دریافت گفتگوها ممکن نشد.'), findsOneWidget);
    expect(find.textContaining('هنوز هیچ گفتگویی'), findsNothing);

    threadsResponse = () => _json([
          {'thread_id': 't-u1', 'title': 'گفتگو با علی محمدی', 'other_party': 'علی محمدی', 'is_admin_chat': true}
        ]);
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();
    expect(find.text('گفتگو با علی محمدی'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sidebar: «پیام‌ها و گفتگوها» shows unread count and opens the conversation list', (tester) async {
    await openUsers(tester, const Size(1440, 900));
    expect(find.descendant(of: find.byType(ListTile), matching: find.text('۳')), findsOneWidget);

    await tester.tap(find.text('پیام‌ها و گفتگوها'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatThreadsPage), findsOneWidget);
    expect(find.text('گفتگو با علی محمدی'), findsOneWidget);
    NotificationPoller.instance.stop();
  });

  for (final size in const [Size(320, 640), Size(390, 844)]) {
    testWidgets('four actions per user card fit on a ${size.width.toInt()}px phone', (tester) async {
      await openUsers(tester, size);
      expect(find.text('گفتگو'), findsNWidgets(2));
      NotificationPoller.instance.stop();
    });
  }
}
