import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:bots/features/discoveries/all_discoveries_page.dart';
import 'package:bots/features/discoveries/discovery_history.dart';
import 'package:bots/preview_discoveries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../exploration/fakes.dart';

class HistoryService extends FakeBotService {
  bool fail = false;
  final cursors = <int>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    if (path == '/explorations') {
      final before = query!['before'] as int;
      cursors.add(before);
      return {
        'items': [
          {
            'taskId': before == 0 ? 'new' : 'old',
            'status': 'completed',
            'completedAt': 1700000000000,
          },
        ],
        'hasMore': before == 0,
        'nextBefore': 10,
      };
    }
    if (fail) throw StateError('offline');
    return {
      'phase': 'complete',
      'cards': [
        {
          'materialId': 'same-material',
          'title': path.contains('/new/') ? '新发现' : '旧发现',
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'push cards live only in the header and receipts wait for visibility',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final seen = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            animate: false,
            onDiscoveryVisible: seen.add,
            messages: [
              const ChatMessage('正常聊天继续保留'),
              ChatMessage(
                '不重复展示的推送汇总',
                turnId: 42,
                referenceTaskId: 'task',
                createdAt: DateTime(2026, 11, 24, 9, 56),
                cards: [previewDiscoveries.first],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('正常聊天继续保留'), findsOneWidget);
      expect(find.text('不重复展示的推送汇总'), findsNothing);
      expect(find.byType(ChatDiscoveryCarousel), findsNothing);
      expect(find.byKey(const ValueKey('chat-time-09:56')), findsNothing);
      expect(seen, isEmpty);
      await tester.tap(find.byTooltip('展开发现'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatDiscoveryCarousel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat-transcript')),
          matching: find.byType(ChatDiscoveryCarousel),
        ),
        findsNothing,
      );
      expect(
        tester.getBottomLeft(find.byType(ChatDiscoveryCarousel)).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const ValueKey('chat-transcript'))).dy,
        ),
      );
      expect(seen, ['task']);
      await tester.tap(find.byTooltip('收起发现'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatDiscoveryCarousel), findsNothing);
      expect(find.text('正常聊天继续保留'), findsOneWidget);
      expect(seen, ['task']);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'history deduplicates home, pages by task, and retries failed page',
    () async {
      final service = HistoryService();
      final history = DiscoveryHistory(
        service: service,
        initial: [
          {'taskId': 'new', 'materialId': 'same-material', 'title': '缓存'},
        ],
      );
      addTearDown(history.dispose);
      await history.loadMore();
      expect(history.cards.length, 1);
      expect(history.cards.first['title'], '新发现');
      service.fail = true;
      await history.loadMore();
      expect(history.error, isNotNull);
      expect(history.cards.length, 1);
      service.fail = false;
      await history.loadMore();
      expect(service.cursors, [0, 10, 10]);
      expect(history.cards.length, 2);
      expect(history.cards.last['taskId'], 'old');
      expect(history.hasMore, isFalse);
    },
  );

  testWidgets('search filters by title/category and opens the matching card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: AllDiscoveriesPage(
          cards: previewDiscoveries,
          onOpen: (card) {
            opened = card;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索发现'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      '音乐',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(previewDiscoveries.first['title'] as String),
      findsNothing,
    );
    await tester.tap(find.text(previewDiscoveries[1]['title'] as String));
    expect(opened?['materialId'], 'music');
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      '不存在',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有找到相关发现'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat discoveries expand, swipe, open detail and collapse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          returningUser: true,
          discoveryCards: previewDiscoveries,
          animate: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-discoveries')), findsNothing);
    await tester.tap(find.byTooltip('展开发现'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-discoveries')), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(previewDiscoveries[1]['title'] as String));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-detail-scroll')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('discovery-detail-scroll'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收起发现'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-discoveries')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
