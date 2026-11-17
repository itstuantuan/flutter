import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_controller.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_artwork.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders separate discoveries and locates the requested material',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var located = 0;
      final messages = [
        ChatMessage(
          '完整后端汇总\n${'第一条内容\n' * 12}【第二条发现】\n第二条正文',
          turnId: 42,
          referenceTaskId: 'exploration-1',
          cards: [
            {
              'materialId': 'material-1',
              'title': '第一条发现',
              'content': '第一条正文\n' * 12,
            },
            {
              'materialId': 'material-2',
              'title': '第二条发现',
              'content': '第二条独立正文',
            },
            {
              'materialId': 'material-3',
              'title': '第三条发现',
              'summary': '第三条独立摘要',
            },
          ],
        ),
        for (var i = 0; i < 30; i++) ChatMessage('后续消息$i', turnId: 100 + i),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            onSend: (_) async => true,
            messages: messages,
            showWelcome: false,
            returningUser: true,
            anchorTurnId: 42,
            anchorMaterialId: 'material-2',
            locationRevision: 1,
            onAnchorVisible: () => located++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('chat-transcript')),
          )
          .controller!;
      expect(scroll.offset, greaterThan(0));
      expect(located, 1);
      expect(find.textContaining('完整后端汇总'), findsNothing);
      expect(
        find.textContaining('第三条独立摘要', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('第二条独立正文', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(ChatBubble), findsNWidgets(30));
      expect(find.byType(ChatDiscoveryCarousel), findsOneWidget);
      final pages = tester.widget<PageView>(find.byType(PageView));
      expect(pages.controller!.page, 1);
      expect(find.textContaining('第二条发现', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'switching material in the same turn relocates and expires the cue',
    (tester) async {
      var located = 0;
      Widget page(String material) => MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          onSend: (_) async => true,
          showWelcome: false,
          messages: const [
            ChatMessage(
              '第一条发现\n第一条正文\n第二条发现\n第二条正文',
              turnId: 42,
              cards: [
                {'materialId': 'one', 'title': '第一条发现'},
                {'materialId': 'two', 'title': '第二条发现'},
              ],
            ),
          ],
          anchorTurnId: 42,
          anchorMaterialId: material,
          onAnchorVisible: () => located++,
        ),
      );
      await tester.pumpWidget(page('one'));
      await tester.pumpAndSettle();
      expect(located, 1);
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).highlightText,
        '第一条发现',
      );
      await tester.pumpWidget(page('two'));
      await tester.pumpAndSettle();
      expect(located, 2);
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).highlightText,
        '第二条发现',
      );
      expect(
        find.byKey(const ValueKey('chat-location-notice')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-location-notice')), findsNothing);
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).highlightText,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'latest horizontal target wins and paging does not move the conversation',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final located = <String>[];
      final messages = [
        const ChatMessage(
          '',
          turnId: 42,
          cards: [
            {'materialId': 'one', 'title': '第一条', 'summary': '第一条摘要'},
            {'materialId': 'two', 'title': '第二条', 'summary': '第二条摘要'},
            {'materialId': 'three', 'title': '第三条', 'summary': '第三条摘要'},
          ],
        ),
        for (var i = 0; i < 20; i++) ChatMessage('后续消息$i', turnId: 100 + i),
      ];
      Widget page(String material, {bool loaded = true, bool motion = true}) =>
          MaterialApp(
            home: ChatPage(
              onExit: () {},
              onExplore: () {},
              onSend: (_) async => true,
              showWelcome: false,
              returningUser: true,
              animate: motion,
              messages: loaded ? messages : const [],
              anchorTurnId: 42,
              anchorMaterialId: material,
              onAnchorVisible: () => located.add(material),
            ),
          );
      await tester.pumpWidget(page('two'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(const ValueKey('chat-location-notice')), findsNothing);
      await tester.pumpWidget(page('three'));
      await tester.pumpAndSettle();
      expect(located, ['three']);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      expect(controller.page, 2);
      final target = tester.getRect(find.text('第三条'));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('chat-transcript')),
      );
      expect(target.top, greaterThan(viewport.top));
      expect(target.bottom, lessThan(viewport.bottom));
      final card = find.byWidgetPredicate(
        (widget) =>
            widget is ChatDiscoveryCard && widget.card['materialId'] == 'three',
      );
      expect(tester.getCenter(card).dx, closeTo(187.5, 1));
      final vertical = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('chat-transcript')),
          )
          .controller!;
      final before = vertical.offset;
      await tester.tap(find.byKey(const ValueKey('discovery-page-0')));
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      expect(vertical.offset, closeTo(before, .1));
      expect(located, ['three']);
      await tester.pumpWidget(const SizedBox());
      located.clear();
      // The target can arrive in the next snapshot with unchanged anchor IDs.
      await tester.pumpWidget(page('three', loaded: false, motion: false));
      await tester.pumpAndSettle();
      expect(located, isEmpty);
      await tester.pumpWidget(page('three', motion: false));
      await tester.pumpAndSettle();
      expect(located, ['three']);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'separate one-card server turns share one carousel and retain source navigation',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ChatController(
        ChatService(
          client: ApiClient(baseUrl: 'https://test'),
          headers: () async => {},
        ),
        displayName: 'Pal',
      );
      addTearDown(controller.dispose);
      controller.merge({
        'turns': [
          for (var id = 1; id <= 3; id++)
            {
              'id': id,
              'messageType': 'discovery',
              'status': 'completed',
              'assistantText': '服务端推送$id',
              'referenceTaskId': 'task-$id',
              'exploration': {
                'cards': [
                  {
                    'materialId': 'same-material',
                    'title': '推送$id',
                    'summary': '第$id条推送摘要',
                  },
                ],
              },
            },
          for (var id = 4; id < 24; id++)
            {
              'id': id,
              'messageType': 'chat',
              'status': 'completed',
              'assistantText': '后续对话$id',
            },
        ],
      });
      final seen = <String>[];
      var located = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            onSend: (_) async => true,
            showWelcome: false,
            returningUser: true,
            messages: controller.messages,
            anchorTurnId: 2,
            anchorMaterialId: 'same-material',
            onDiscoveryVisible: seen.add,
            onAnchorVisible: () => located++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatDiscoveryCarousel), findsOneWidget);
      final carousel = tester.widget<ChatDiscoveryCarousel>(
        find.byType(ChatDiscoveryCarousel),
      );
      expect(carousel.cards.length, 3);
      expect(carousel.cards.map((c) => c['_chatTurnId']), [1, 2, 3]);
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, 1);
      expect(located, 1);
      expect(seen, ['task-2']);
      final selected = find.byWidgetPredicate(
        (w) => w is ChatDiscoveryCard && w.highlighted,
      );
      expect(selected, findsOneWidget);
      expect(tester.widget<ChatDiscoveryCard>(selected).card['_chatTurnId'], 2);
      expect(tester.getCenter(selected).dx, closeTo(187.5, 1));
      await tester.tap(find.byKey(const ValueKey('discovery-page-2')));
      await tester.pumpAndSettle();
      expect(pages.page, 2);
      expect(seen, ['task-2', 'task-3']);
      // Display grouping never rewrites the controller's server messages.
      expect(controller.messages.take(3).map((m) => m.turnId), [1, 2, 3]);
      expect(
        controller.messages.take(3).every((m) => m.cards.length == 1),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
