import 'package:bots/features/home/home_interactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hint persists first presentation and stays hidden on reentry', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: FirstHomeChatHint(userId: 'first-user')),
    );
    await tester.pump();
    expect(find.text('快跟我聊聊吧'), findsOneWidget);
    await tester.pump();
    expect(
      await const FlutterSecureStorage().read(
        key: 'home.chat-hint.seen.v1.first-user',
      ),
      'true',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: FirstHomeChatHint(userId: 'first-user')),
    );
    await tester.pump();
    expect(find.text('快跟我聊聊吧'), findsNothing);
  });
  testWidgets('saved hint remains hidden after a new app session', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'home.chat-hint.seen.v1.saved-user': 'true',
    });
    await tester.pumpWidget(
      const MaterialApp(home: FirstHomeChatHint(userId: 'saved-user')),
    );
    await tester.pump();
    expect(find.text('快跟我聊聊吧'), findsNothing);
  });
  testWidgets('press scales down and cancel restores without invoking action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HomePressFeedback(
            child: TextButton(onPressed: () => taps++, child: const Text('按钮')),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('按钮')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .95);
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(taps, 0);
  });
}
