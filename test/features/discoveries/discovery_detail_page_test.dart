import 'dart:async';

import 'package:bots/features/discoveries/discovery_detail_page.dart';
import 'package:bots/features/chat/chat_controller.dart';

import '../exploration/fakes.dart';

import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const card = <String, dynamic>{
  'taskId': 'task',
  'materialId': 'cat',
  'title': '奶牛猫的花纹',
  'content': '真实发现正文',
  'tags': ['宠物', '猫咪'],
};

void main() {
  testWidgets(
    'quoted draft survives failure and clears only after acceptance',
    (tester) async {
      var response = Completer<bool>();
      final changes = <Map<String, dynamic>?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            animate: false,
            showWelcome: false,
            referenceCard: card,
            onReferenceChanged: changes.add,
            onSend: (_) => response.future,
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, 'why?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(find.byKey(const ValueKey('discovery-reference')), findsOneWidget);
      response.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'why?');
      expect(changes, isEmpty);
      response = Completer<bool>();
      tester.widget<TextField>(field).onSubmitted!('why?');
      await tester.pump();
      response.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-reference')), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(changes, [null]);
    },
  );
  test('accepted quote is not attached to the next message', () async {
    final service = FakeBotService();
    final controller = ChatController(service, displayName: 'Pal');
    await controller.initializeSession();
    controller.referenceDiscovery(card);
    expect(await controller.send('why?'), isTrue);
    expect(controller.referenceMaterialId, isNull);
    expect(await controller.send('next'), isTrue);
    final posts = service.calls
        .where(
          (c) =>
              c['method'] == 'POST' &&
              (c['path'] as String).endsWith('/messages'),
        )
        .toList();
    expect((posts.first['data'] as Map)['referenceMaterialId'], 'cat');
    expect(
      (posts.last['data'] as Map).containsKey('referenceMaterialId'),
      isFalse,
    );
    controller.dispose();
    await service.events.close();
  });

  test('reference identity is sent and removed on cancellation', () async {
    final service = FakeBotService();
    final controller = ChatController(service, displayName: 'Pal');
    await controller.initializeSession();
    controller.referenceDiscovery(card);
    expect(controller.submitText('聊聊这条发现'), isTrue);
    await Future<void>.delayed(Duration.zero);
    final quoted =
        service.calls.lastWhere(
              (call) =>
                  call['method'] == 'POST' &&
                  (call['path'] as String).endsWith('/messages'),
            )['data']
            as Map;
    expect(quoted['referenceTaskId'], 'task');
    expect(quoted['referenceMaterialId'], 'cat');
    controller.referenceDiscovery(null);
    expect(controller.submitText('普通对话'), isTrue);
    await Future<void>.delayed(Duration.zero);
    final plain =
        service.calls.lastWhere(
              (call) =>
                  call['method'] == 'POST' &&
                  (call['path'] as String).endsWith('/messages'),
            )['data']
            as Map;
    expect(plain.containsKey('referenceTaskId'), isFalse);
    expect(plain.containsKey('referenceMaterialId'), isFalse);
    controller.dispose();
    await service.events.close();
  });

  testWidgets('short detail keeps chat action anchored at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: DiscoveryDetailPage(card: card)),
    );
    await tester.pumpAndSettle();
    final action = find.ancestor(
      of: find.text('和Pal聊聊'),
      matching: find.byType(TextButton),
    );
    expect(tester.getBottomRight(action).dy, 800);
  });

  testWidgets(
    'chat detail returns the chosen discovery as a removable reference',
    (tester) async {
      Map<String, dynamic>? reference;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            animate: false,
            showWelcome: false,
            returningUser: true,
            discoveryCards: const [card],
            onReferenceChanged: (value) => reference = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('展开发现'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChatDiscoveryCard));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryDetailPage), findsOneWidget);
      expect(find.text('真实发现正文'), findsOneWidget);
      await tester.tap(find.text('和Pal聊聊'));
      await tester.pumpAndSettle();
      expect(reference?['materialId'], 'cat');
      expect(find.byKey(const ValueKey('discovery-reference')), findsOneWidget);
      await tester.tap(find.byTooltip('取消引用'));
      await tester.pumpAndSettle();
      expect(reference, isNull);
      expect(find.byKey(const ValueKey('discovery-reference')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail long content is reachable on small screens and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(320, 568),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DiscoveryDetailPage(
              card: {
                ...card,
                'content': List.filled(30, '完整正文可以滚动阅读。').join('\n'),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('discovery-detail-scroll')),
          const Offset(0, -6000),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('喜欢'));
        await tester.tap(find.text('喜欢'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('和Pal聊聊').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('detail has no history entry and chat returns its identity', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    const second = {
      'taskId': 'other-task',
      'materialId': 'dog',
      'title': '狗狗发现',
      'content': '第二条正文',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiscoveryDetailPage(
                    card: card,
                    history: [card, second],
                  ),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('历史'), findsNothing);
    expect(find.byIcon(Icons.history), findsNothing);
    await tester.tap(find.text('和Pal聊聊'));
    await tester.pumpAndSettle();
    expect(selected?['taskId'], card['taskId']);
    expect(selected?['materialId'], card['materialId']);
  });
}
