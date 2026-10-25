import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/core/storage/session_store.dart';
import 'package:qrdify/features/auth/domain/auth_session.dart';
import 'package:qrdify/features/auth/domain/auth_user.dart';
import 'package:qrdify/features/notifications/data/mobile_push_service.dart';
import 'package:qrdify/features/notifications/data/notification_repository_impl.dart';
import 'package:qrdify/features/notifications/domain/app_notification.dart';
import 'package:qrdify/features/notifications/domain/notification_repository.dart';
import 'package:qrdify/features/notifications/domain/notification_signals.dart';
import 'package:qrdify/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:qrdify/features/notifications/presentation/pages/notifications_page.dart';
import 'package:qrdify/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:qrdify/core/theme/app_theme.dart';

const unread = AppNotification(
  id: 'new',
  type: 'time_in',
  title: 'Student time-in',
  message: 'Attendance recorded.',
  createdAt: null,
);

void main() {
  setUp(() {
    NotificationSignals.openRequest.value = null;
    NotificationSignals.pushStatus.value = null;
  });

  testWidgets('unread badge refreshes after reads without opening the inbox', (
    tester,
  ) async {
    final repo = _Repository()
      ..page = const NotificationPageResult(
        items: [unread],
        currentPage: 1,
        lastPage: 2,
        unreadCount: 4,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBadge(
            repository: repo,
            accessToken: 'session',
            childId: 42,
            child: const Icon(Icons.notifications),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(
      tester.widget<Badge>(find.byType(Badge)).backgroundColor,
      AppColors.danger,
    );
    expect(repo.lastChild, 42);
    expect(repo.lastUnreadOnly, isTrue);

    final controller = NotificationController(repo, 'session', childId: 42);
    await controller.load();
    repo.page = const NotificationPageResult(
      items: [],
      currentPage: 1,
      lastPage: 1,
      unreadCount: 3,
    );
    await controller.markRead(unread);
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    repo.page = const NotificationPageResult(
      items: [],
      currentPage: 1,
      lastPage: 1,
      unreadCount: 0,
    );
    await controller.markAllRead();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a previous child response cannot restore its unread badge', (
    tester,
  ) async {
    final pending = Completer<NotificationPageResult>();
    final repo = _Repository()..pending = pending;
    Widget badge(int childId) => MaterialApp(
      home: Scaffold(
        body: NotificationBadge(
          repository: repo,
          accessToken: 'session',
          childId: childId,
          child: const Icon(Icons.notifications),
        ),
      ),
    );
    await tester.pumpWidget(badge(42));
    repo.pending = null;
    await tester.pumpWidget(badge(43));
    await tester.pumpAndSettle();
    pending.complete(
      const NotificationPageResult(
        items: [unread],
        currentPage: 1,
        lastPage: 1,
        unreadCount: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(repo.lastChild, 43);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('badge polls only while resumed and reacts to incoming alerts', (
    tester,
  ) async {
    final repo = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBadge(
            repository: repo,
            accessToken: 'session',
            child: const Icon(Icons.notifications),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repo.page = const NotificationPageResult(
      items: [unread],
      currentPage: 1,
      lastPage: 1,
    );
    NotificationSignals.received();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final before = repo.fetchCalls;
    await tester.pump(const Duration(seconds: 16));
    expect(repo.fetchCalls, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.fetchCalls, greaterThan(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'both API modes use matching routes and transmit the selected child',
    () async {
      for (final mobile in [false, true]) {
        final requests = <http.Request>[];
        final api = ApiClient(
          baseUrl: mobile
              ? 'https://school.test/api/mobile/v1/'
              : 'https://school.test/api/',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(
                request.method == 'GET'
                    ? {
                        'data': [],
                        'current_page': 1,
                        'last_page': 1,
                        'unread_count': 7,
                        'total_count': 24,
                      }
                    : {'message': 'OK'},
              ),
              200,
            );
          }),
        );
        final repo = NotificationRepositoryImpl(api, mobile);
        final result = await repo.fetchNotifications(
          accessToken: 'session',
          childId: 42,
          unreadOnly: true,
        );
        expect(result.unreadCount, 7);
        expect(result.totalCount, 24);
        final base = mobile
            ? '/api/mobile/v1/notifications'
            : '/api/notifications';
        expect(requests[0].url.path, base);
        expect(requests[0].url.queryParameters['student_id'], '42');
        expect(requests[0].url.queryParameters['unread'], '1');
        await repo.markRead(accessToken: 'session', id: 'id');
        expect(
          requests[1].url.path,
          '$base/id/${mobile ? 'read' : 'mark-as-read'}',
        );
        await repo.markAllRead(accessToken: 'session', childId: 42);
        expect(jsonDecode(requests[2].body), {'student_id': 42});
      }
    },
  );

  test(
    'unread count includes unloaded pages and read-all remains available',
    () async {
      final repo = _Repository();
      repo.page = NotificationPageResult(
        items: [unread.markRead()],
        currentPage: 1,
        lastPage: 2,
        totalCount: 30,
        unreadCount: 5,
      );
      final controller = NotificationController(repo, 'session', childId: 42);
      await controller.load();
      expect(controller.unreadCount, 5);
      expect(controller.totalCount, 30);
      expect(await controller.markAllRead(), isTrue);
      expect(repo.markAllChild, 42);
      expect(repo.markAllCalls, 1);
      expect(controller.unreadCount, 0);
      controller.dispose();
    },
  );

  test(
    'an earlier refresh cannot undo a successfully read notification',
    () async {
      final repo = _Repository();
      repo.page = const NotificationPageResult(
        items: [unread],
        currentPage: 1,
        lastPage: 1,
        unreadCount: 1,
      );
      final controller = NotificationController(repo, 'session');
      await controller.load();
      final response = Completer<NotificationPageResult>();
      repo.pending = response;
      final refresh = controller.load(refresh: true);
      expect(await controller.markRead(unread), isTrue);
      response.complete(repo.page);
      await refresh;
      expect(controller.items.single.isRead, isTrue);
      expect(controller.unreadCount, 0);
      controller.dispose();
    },
  );

  test('unread filtering is requested from the server', () async {
    final repo = _Repository();
    final controller = NotificationController(repo, 'session', childId: 42);
    await controller.setUnreadOnly(true);
    expect(repo.lastUnreadOnly, isTrue);
    expect(repo.lastChild, 42);
    controller.dispose();
  });

  test(
    'missing notifications data is rejected instead of showing caught-up',
    () {
      expect(
        () => NotificationPageResult.fromJson({'unexpected': true}),
        throwsFormatException,
      );
      final item = AppNotification.fromJson({
        'id': 'x',
        'data': {
          'student_id': 42,
          'student_name': 'Child',
          'occurred_at': '2026-10-23T07:00:00+08:00',
        },
      });
      expect(item.childId, 42);
      expect(item.markRead().childName, 'Child');
    },
  );

  testWidgets(
    'an empty inbox refreshes by pulling and polls only while visible',
    (tester) async {
      final repo = _Repository();
      Widget page(bool active) => MaterialApp(
        home: NotificationsPage(
          accessToken: 'session',
          repository: repo,
          isActive: active,
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(repo.fetchCalls, 1);
      repo.page = const NotificationPageResult(
        items: [unread],
        currentPage: 1,
        lastPage: 1,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Student time-in'), findsOneWidget);
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      final before = repo.fetchCalls;
      await tester.pump(const Duration(seconds: 16));
      expect(repo.fetchCalls, before);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(repo.fetchCalls, greaterThan(before));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('push binds to the current session, ignores other accounts, and deduplicates foreground banners', () async {
    final client = _PushClient();
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://school.test/api/',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode({'enabled': true}), 200);
      }),
    );
    final service = MobilePushService(api, _Store(), client: client);
    final session = AuthSession(
      accessToken: 'parent-session',
      user: AuthUser.fromJson({
        'id': 10,
        'roles': ['parent'],
      }),
    );
    await service.updateSession(session);
    expect(
      requests.where((r) => r.method == 'POST').single.headers['Authorization'],
      'Bearer parent-session',
    );
    final epoch = NotificationSignals.refresh.value;
    client.messagesController.add({
      'notification_id': 'other',
      'user_id': '11',
    });
    client.messagesController.add({'notification_id': 'once', 'user_id': '10'});
    client.messagesController.add({'notification_id': 'once', 'user_id': '10'});
    await Future<void>.delayed(Duration.zero);
    expect(client.shown, 1);
    expect(NotificationSignals.refresh.value, epoch + 1);
    client.openController.add({
      'notification_id': 'once',
      'user_id': '10',
      'student_id': '42',
    });
    await Future<void>.delayed(Duration.zero);
    expect(NotificationSignals.openRequest.value?['student_id'], '42');
    await service.updateSession(null);
    expect(requests.last.method, 'DELETE');
    expect(client.deleted, isTrue);
    expect(NotificationSignals.openRequest.value, isNull);
    service.dispose();
    await client.close();
  });

  test('denying phone permission leaves the app inbox usable without registering a device', () async {
    final client = _PushClient()..allowed = false;
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'https://school.test/api/',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('{"enabled":true}', 200);
      }),
    );
    final service = MobilePushService(api, _Store(), client: client);
    await service.updateSession(
      AuthSession(
        accessToken: 'session',
        user: AuthUser.fromJson({
          'id': 1,
          'roles': ['parent'],
        }),
      ),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(NotificationSignals.pushStatus.value, contains('off'));
    service.dispose();
    await client.close();
  });
}

class _Repository implements NotificationRepository {
  NotificationPageResult page = const NotificationPageResult(
    items: [],
    currentPage: 1,
    lastPage: 1,
  );
  Completer<NotificationPageResult>? pending;
  int fetchCalls = 0, markAllCalls = 0;
  int? lastChild, markAllChild;
  bool lastUnreadOnly = false;
  @override
  bool get supportsDeletion => true;
  @override
  Future<NotificationPageResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int perPage = 20,
    int? childId,
    bool unreadOnly = false,
  }) async {
    fetchCalls++;
    lastChild = childId;
    lastUnreadOnly = unreadOnly;
    return pending == null ? this.page : pending!.future;
  }

  @override
  Future<void> markRead({
    required String accessToken,
    required String id,
  }) async {}
  @override
  Future<void> markAllRead({required String accessToken, int? childId}) async {
    markAllCalls++;
    markAllChild = childId;
  }

  @override
  Future<void> deleteNotification({
    required String accessToken,
    required String id,
  }) async {}
}

class _Store implements SessionStore {
  @override
  Future<String> getOrCreateInstallationId() async =>
      '1de1f3e3-80f0-41f8-bf79-bbdc4267be89';
  @override
  Future<void> clearAccessToken() async {}
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<void> writeAccessToken(String token, {DateTime? expiresAt}) async {}
}

class _PushClient implements PushClient {
  bool allowed = true, deleted = false;
  int shown = 0;
  final messagesController = StreamController<Map<String, dynamic>>.broadcast();
  final openController = StreamController<Map<String, dynamic>>.broadcast();
  final tokenController = StreamController<String>.broadcast();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<bool> permissionEnabled() async => allowed;
  @override
  Future<String?> getToken() async => 'test-registration-token';
  @override
  Future<void> deleteToken() async {
    deleted = true;
  }

  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;
  @override
  Stream<Map<String, dynamic>> get messages => messagesController.stream;
  @override
  Stream<Map<String, dynamic>> get opens => openController.stream;
  @override
  Stream<String> get tokenChanges => tokenController.stream;
  @override
  Future<void> showForeground(Map<String, dynamic> data) async {
    shown++;
  }

  Future<void> close() async {
    await messagesController.close();
    await openController.close();
    await tokenController.close();
  }
}
