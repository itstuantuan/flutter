import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_artwork.dart';
import 'package:bots/features/chat/chat_page.dart';
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
      expect(find.byType(ChatBubble), findsNWidgets(33));
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
}
