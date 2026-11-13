import 'package:bots/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hint keeps looping beyond three cycles without moving or blocking chat',
    (tester) async {
      var chats = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            onMenu: () {},
            onExplore: () {},
            onChat: () => chats++,
            onVoice: () {},
            onDiscovery: (_) {},
          ),
        ),
      );
      await tester.pump();
      final hitbox = tester.getRect(find.byTooltip('聊天'));
      final ring = find.byKey(const ValueKey('home-chat-ring'));
      final initial = tester.widget<Transform>(ring).transform.clone();
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.widget<Transform>(ring).transform, isNot(initial));
      expect(tester.getRect(find.byTooltip('聊天')), hitbox);
      await tester.pump(const Duration(milliseconds: 7800));
      expect(tester.widget<Transform>(ring).transform, isNot(initial));
      final afterThreeCycles = tester.widget<Transform>(ring).transform.clone();
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.widget<Transform>(ring).transform, isNot(afterThreeCycles));
      expect(tester.getRect(find.byTooltip('聊天')), hitbox);
      await tester.tap(find.byTooltip('聊天'));
      expect(chats, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion keeps hint still', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: HomePage(
            onMenu: () {},
            onExplore: () {},
            onChat: () {},
            onVoice: () {},
            onDiscovery: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('home-chat-ring'));
    final initial = tester.widget<Transform>(ring).transform.clone();
    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.widget<Transform>(ring).transform, initial);
    await tester.pumpWidget(const SizedBox());
  });
}
