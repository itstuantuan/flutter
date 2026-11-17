import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_artwork.dart';
import 'package:bots/features/chat/chat_controller.dart';
import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/chat/chat_time.dart';
import 'package:bots/features/chat/chat_typewriter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timestamps group at five minutes and preserve calendar dates', () {
    final now = DateTime(2026, 11, 16, 13, 15);
    expect(showChatTime(null, now), isTrue);
    expect(
      showChatTime(now.subtract(const Duration(minutes: 4)), now),
      isFalse,
    );
    expect(showChatTime(now.subtract(const Duration(minutes: 5)), now), isTrue);
    expect(
      showChatTime(DateTime(2026, 11, 15, 23, 59), DateTime(2026, 11, 16)),
      isTrue,
    );
    expect(showChatTime(now, null), isFalse);
    expect(formatChatTime(now, now: now), '13:15');
    expect(formatChatTime(DateTime(2026, 11, 15, 11, 3), now: now), '昨天 11:03');
    expect(
      formatChatTime(DateTime(2025, 11, 15, 11, 3), now: now),
      '2025年11月15日 11:03',
    );
  });

  test('server creation time stays fixed as live snapshots update', () {
    final controller = ChatController(
      ChatService(
        client: ApiClient(baseUrl: 'https://test'),
        headers: () async => {},
      ),
      displayName: 'test',
    );
    final created = DateTime(2026, 11, 16, 13, 10).millisecondsSinceEpoch;
    final turn = {
      'id': 1,
      'userText': '你好',
      'assistantText': '你',
      'createTime': created,
      'updateTime': created,
      'messageType': 'chat',
    };
    controller.merge({
      'turns': [turn],
    });
    expect(controller.messages.last.animateReply, isFalse);
    controller.merge({
      'turns': [
        {...turn, 'assistantText': '你好！', 'updateTime': created + 600000},
      ],
    }, live: true);
    expect(
      controller.messages.every(
        (m) => m.createdAt?.millisecondsSinceEpoch == created,
      ),
      isTrue,
    );
    expect(controller.messages.last.animateReply, isTrue);
    controller.dispose();
  });

  testWidgets(
    'history stays complete, only newly received replies type progressively',
    (tester) async {
      Widget page(List<ChatMessage> messages) => MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          onSend: (_) async => true,
          showWelcome: false,
          messages: messages,
        ),
      );
      final first = ChatMessage(
        '历史内容不重播',
        turnId: 1,
        createdAt: DateTime(2026, 11, 16, 13, 10),
      );
      await tester.pumpWidget(page([first]));
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).text,
        first.text,
      );
      final second = ChatMessage(
        '新的回复逐字显示 👨‍👩‍👧‍👦，不会拆开组合表情。',
        turnId: 2,
        createdAt: DateTime(2026, 11, 16, 13, 15),
        animateReply: true,
      );
      await tester.pumpWidget(page([first, second]));
      await tester.pump(const Duration(milliseconds: 80));
      final partial = tester
          .widget<ChatBubble>(find.byType(ChatBubble).last)
          .text;
      expect(partial.length, lessThan(second.text.length));
      expect(second.text.startsWith(partial), isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble).last).text,
        second.text,
      );
      expect(
        find.byKey(ValueKey('chat-time-${formatChatTime(first.createdAt!)}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('chat-time-${formatChatTime(second.createdAt!)}')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'streaming text catches up without restart and respects reduced motion',
    (tester) async {
      Widget bubble(String text, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: ChatTypewriter(text: text, animate: true),
        ),
      );
      await tester.pumpWidget(bubble('你好👨‍👩‍👧‍👦'));
      await tester.pump(const Duration(milliseconds: 24));
      expect(tester.widget<ChatBubble>(find.byType(ChatBubble)).text, '你');
      await tester.pumpWidget(bubble('你好👨‍👩‍👧‍👦，新片段'));
      expect(tester.widget<ChatBubble>(find.byType(ChatBubble)).text, '你');
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).text,
        '你好👨‍👩‍👧‍👦，新片段',
      );
      await tester.pumpWidget(bubble('服务端修正后的内容', reduced: true));
      expect(
        tester.widget<ChatBubble>(find.byType(ChatBubble)).text,
        '服务端修正后的内容',
      );
    },
  );
}
