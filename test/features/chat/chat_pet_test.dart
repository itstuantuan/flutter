import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(390, 844);
const _viewport = Rect.fromLTRB(0, 100, 390, 760);

Future<void> run(WidgetTester tester, int milliseconds) async {
  for (var t = 0; t < milliseconds; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('placement', () {
    const reply = PetPerch(
      ('r', 1),
      ChatPetPerchKind.reply,
      Rect.fromLTRB(16, 600, 200, 700),
      3,
    );

    test('stands beside a reply on its right, feet on its bottom', () {
      final at = petOffset(
        (anchor: reply.id, spot: PetSpot.beside, edge: 0),
        perches: const [reply],
        viewport: _viewport,
        stage: _screen,
      )!;
      expect(at.dx, greaterThan(reply.rect.right - ChatPet.size.width * .2));
      expect(at.dy + ChatPet.size.height, reply.rect.bottom);
    });

    test('rejects a spot that would cover another bubble', () {
      const user = PetPerch(
        ('u', 2),
        ChatPetPerchKind.user,
        Rect.fromLTRB(150, 560, 374, 596),
        2,
      );
      const short = PetPerch(
        ('r', 3),
        ChatPetPerchKind.reply,
        Rect.fromLTRB(16, 610, 120, 640),
        3,
      );
      final perches = [user, short];
      expect(
        petFits(
          (anchor: short.id, spot: PetSpot.beside, edge: 0),
          perches: perches,
          viewport: _viewport,
          stage: _screen,
        ),
        isFalse,
      );
      expect(
        petFits(
          (anchor: reply.id, spot: PetSpot.beside, edge: 0),
          perches: const [reply],
          viewport: _viewport,
          stage: _screen,
        ),
        isTrue,
      );
    });

    test('edge slot skips text that reaches the screen edge', () {
      const user = PetPerch(
        ('u', 1),
        ChatPetPerchKind.user,
        Rect.fromLTRB(100, 680, 390, 760),
        1,
      );
      final fraction = petFreeEdge(
        const [user],
        viewport: _viewport,
        stage: _screen,
      );
      expect(fraction, lessThan(1));
    });
  });

  group('in the chat page', () {
    setUp(() => ChatPet.enabled = true);
    tearDown(() => ChatPet.enabled = false);

    Future<void> open(WidgetTester tester, List<ChatMessage> messages) async {
      tester.view.physicalSize = _screen * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            returningUser: true,
            showWelcome: false,
            messages: messages,
            onExit: () {},
            onExplore: () {},
          ),
        ),
      );
      await run(tester, 600);
    }

    Rect pet(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('chat-pet')));

    testWidgets('rests beside the newest reply', (tester) async {
      await open(tester, const [
        ChatMessage('你好', isUser: true, turnId: 1),
        ChatMessage('嗨，今天想聊点什么？', turnId: 2),
      ]);
      final bubble = tester.getRect(find.text('嗨，今天想聊点什么？'));
      final rect = pet(tester);
      expect(rect.left, greaterThan(bubble.right));
      expect(rect.bottom, moreOrLessEquals(bubble.bottom + 12, epsilon: 14));
    });

    testWidgets('retreats to the edge while reading history, then returns', (
      tester,
    ) async {
      await open(tester, [
        for (var i = 0; i < 30; i++)
          ChatMessage('第 $i 条消息', isUser: i.isOdd, turnId: i),
      ]);
      final resting = pet(tester);
      expect(resting.right, lessThan(_screen.width));

      await tester.drag(
        find.byKey(const ValueKey('chat-transcript')),
        const Offset(0, 300),
      );
      await run(tester, 1500);
      expect(pet(tester).right, greaterThan(_screen.width));

      await tester.drag(
        find.byKey(const ValueKey('chat-transcript')),
        const Offset(0, -2000),
      );
      await run(tester, 2500);
      expect(pet(tester).right, lessThan(_screen.width));
    });

    testWidgets('a drag that starts on the pet still scrolls the chat', (
      tester,
    ) async {
      await open(tester, [
        for (var i = 0; i < 30; i++)
          ChatMessage('第 $i 条消息', isUser: i.isOdd, turnId: i),
      ]);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('chat-transcript')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.dragFrom(pet(tester).center, const Offset(0, 200));
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(100));
    });

    testWidgets('tapping the pet reacts without breaking the page', (
      tester,
    ) async {
      await open(tester, const [ChatMessage('嗨', turnId: 1)]);
      await tester.tapAt(pet(tester).center);
      await run(tester, 2000);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('chat-pet')), findsOneWidget);
    });
  });
}
