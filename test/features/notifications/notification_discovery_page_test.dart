import 'dart:async';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:bots/features/notifications/notification_discovery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'push_binding_service_test.dart' show accountFor, sessionFor;

class LocatedService extends ChatService {
  LocatedService()
    : super(
        client: ApiClient(baseUrl: 'https://test'),
        headers: () async => {},
      );
  final calls = <String>[];
  Object? error;
  Completer<void>? gate;
  String session = 'old-session';
  final streams = <String>[];
  final events = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> subscribe(String sessionId, CancelToken cancel) {
    streams.add(sessionId);
    return events.stream;
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    calls.add(path);
    if (path == '/explorations/old-task/progress') {
      return {
        'phase': 'complete',
        'cards': [
          {'materialId': 'material-1'},
        ],
      };
    }
    if (!path.contains('/locate/')) {
      return {'sessionId': 'old-session', 'turns': []};
    }
    await gate?.future;
    if (error != null) throw error!;
    return {
      'sessionId': session,
      'anchorTurnId': 1,
      'turns': [
        {'id': 0, 'messageType': 'normal', 'assistantText': '原来的对话内容'},
        for (var i = 1; i <= 5; i++)
          {
            'id': i,
            'messageType': 'discovery',
            'status': 'completed',
            'referenceTaskId': i == 1 ? 'old-task' : 'latest-task',
            'exploration': {
              'cards': [
                {
                  'materialId': 'material-$i',
                  'title': i == 1 ? '历史发现' : '最新发现$i',
                  'content': i == 1 ? '历史内容' : '最新内容$i',
                },
              ],
            },
          },
      ],
    };
  }
}

const notification = ExplorationNotification(
  taskId: 'old-task',
  sessionId: 'old-session',
  notificationId: 'push-id',
);

Widget notificationApp(NotificationDiscoveryPage page) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: page,
);

void main() {
  test('only accepts complete exploration completion notifications', () {
    expect(
      ExplorationNotification.parse({
        'type': 'discovery',
        'discoveryId': 'old-task',
      }),
      isNull,
    );
    expect(
      ExplorationNotification.parse({
        'event': 'exploration_completed',
        'taskId': 't',
        'sessionId': 's',
      }),
      isNull,
    );
    expect(
      ExplorationNotification.parse({
        'event': 'exploration_completed',
        'taskId': 't',
        'sessionId': 's',
        'notificationId': 'n',
      })?.taskId,
      't',
    );
  });

  testWidgets(
    'opens an authorized historical card outside the latest three and acknowledges after display',
    (tester) async {
      final account = await accountFor('A');
      final lookup = Completer<void>();
      final service = LocatedService()..gate = lookup;
      addTearDown(service.events.close);
      var acknowledgements = 0;
      await tester.pumpWidget(
        notificationApp(
          NotificationDiscoveryPage(
            notification: notification,
            account: account,
            session: account.session!,
            service: service,
            onDisplayed: (task) async {
              expect(task, 'old-task');
              acknowledgements++;
            },
          ),
        ),
      );
      final initialChat = tester.element(find.byType(ChatPage));
      expect(find.text('探索发现'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      lookup.complete();
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(ChatPage)), same(initialChat));
      expect(
        service.calls.first,
        '/sessions/old-session/messages/locate/old-task',
      );
      expect(service.calls, contains('/sessions/old-session/messages'));
      expect(service.calls, isNot(contains('/me')));
      expect(service.streams, ['old-session']);
      final chat = tester.widget<ChatPage>(find.byType(ChatPage));
      expect(chat.anchorTurnId, 1);
      expect(chat.anchorMaterialId, 'material-1');
      expect(chat.messages.map((message) => message.text), contains('原来的对话内容'));
      expect(find.text('历史发现'), findsOneWidget);
      expect(
        tester
            .widgetList<ChatDiscoveryCarousel>(
              find.byType(ChatDiscoveryCarousel),
            )
            .expand((carousel) => carousel.cards)
            .map((card) => card['materialId']),
        ['material-1', 'material-2', 'material-3', 'material-4', 'material-5'],
      );
      expect(acknowledgements, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '404 never shows content or acknowledges and a failed load can be retried',
    (tester) async {
      final account = await accountFor('A');
      final service = LocatedService()
        ..error = DioException(
          requestOptions: RequestOptions(path: '/locate'),
          response: Response(
            requestOptions: RequestOptions(path: '/locate'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        );
      addTearDown(service.events.close);
      var acknowledgements = 0;
      await tester.pumpWidget(
        notificationApp(
          NotificationDiscoveryPage(
            notification: notification,
            account: account,
            session: account.session!,
            service: service,
            onDisplayed: (_) async {
              acknowledgements++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('这条发现不存在，或不属于当前账号。'), findsOneWidget);
      expect(find.byType(ChatDiscoveryCarousel), findsNothing);
      expect(acknowledgements, 0);
      service.error = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('历史发现'), findsOneWidget);
      expect(acknowledgements, 1);
    },
  );

  testWidgets('rejects a late result after changing accounts', (tester) async {
    final account = await accountFor('A');
    final gate = Completer<void>();
    final service = LocatedService()..gate = gate;
    addTearDown(service.events.close);
    var acknowledgements = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationDiscoveryPage(
          notification: notification,
          account: account,
          session: account.session!,
          service: service,
          onDisplayed: (_) async {
            acknowledgements++;
          },
        ),
      ),
    );
    await account.store.write(sessionFor('B'));
    await account.restoreSession();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ChatDiscoveryCarousel), findsNothing);
    expect(find.text('账号已变化，请返回后重新打开通知。'), findsOneWidget);
    expect(acknowledgements, 0);
  });

  testWidgets('rejects a mismatched session response', (tester) async {
    final account = await accountFor('A');
    final service = LocatedService()..session = 'another-session';
    addTearDown(service.events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationDiscoveryPage(
          notification: notification,
          account: account,
          session: account.session!,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法确认这条发现，请重试。'), findsOneWidget);
    expect(find.byType(ChatDiscoveryCarousel), findsNothing);
  });
}
