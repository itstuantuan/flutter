import 'package:bots/features/chat/chat_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('both bubbles fit short text and wrap long text at max width', (
    tester,
  ) async {
    for (final isUser in [true, false]) {
      Future<void> show(String text) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              child: ChatBubble(text: text, isUser: isUser),
            ),
          ),
        ),
      );
      Finder box() => find
          .descendant(of: find.byType(ChatBubble), matching: find.byType(Stack))
          .first;
      await show('你好啊');
      final short = tester.getSize(box());
      expect(short.width, lessThan(94));
      expect(short.width, greaterThan(42));
      await show('这是一条需要自动换行的长消息。' * 20);
      final long = tester.getSize(box());
      expect(long.width, 269);
      expect(long.height, greaterThan(short.height));
      expect(tester.takeException(), isNull);
    }
  });
}
