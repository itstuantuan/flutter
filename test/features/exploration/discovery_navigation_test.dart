import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/exploration/exploration_controller.dart';
import 'package:bots/features/exploration/live_plaza_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'selecting the second plaza card locates and animates its chat card',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeBotService();
      final cards = (discoveryTurn()['exploration'] as Map)['cards'] as List;
      service.progress = {'phase': 'complete', 'cards': cards};
      service.located = {
        'anchorTurnId': 42,
        'turns': [
          for (var i = 0; i < 3; i++)
            {
              ...discoveryTurn(id: 42 + i),
              'exploration': {
                'cards': [cards[i]],
              },
            },
          for (var i = 0; i < 15; i++)
            {
              'id': 100 + i,
              'messageType': 'chat',
              'status': 'completed',
              'assistantText': '后续对话$i',
            },
        ],
      };
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      var located = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => LivePlazaPage(
              controller: controller,
              taskId: 'task-1',
              onChat: (_) async {},
              onOpenDiscovery: (task, material) async {
                expect(material, 'material-2');
                expect(
                  await controller.chat.locate(task, materialId: material),
                  isTrue,
                );
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatPage(
                      onExit: () => Navigator.pop(context),
                      onExplore: () {},
                      onSend: (_) async => true,
                      showWelcome: false,
                      returningUser: true,
                      messages: controller.chat.messages,
                      anchorTurnId: controller.chat.anchorTurnId,
                      anchorMaterialId: controller.chat.referenceMaterialId,
                      onAnchorVisible: () => located = true,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plaza-discovery-trigger')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-330, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看内容').hitTestable());
      await tester.pump();
      // Stop as soon as location completes, before the breathing cue finishes.
      for (var i = 0; i < 40 && !located; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(located, isTrue);
      expect(controller.chat.anchorTurnId, 43);
      expect(controller.chat.referenceTaskId, 'task-1');
      expect(controller.chat.referenceMaterialId, 'material-2');
      expect(find.byType(ChatDiscoveryCarousel), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      final target = find.byWidgetPredicate(
        (w) => w is ChatDiscoveryCard && w.highlighted,
      );
      expect(
        tester.widget<ChatDiscoveryCard>(target).card['materialId'],
        'material-2',
      );
      final rect = tester.getRect(target);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('chat-transcript')),
      );
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
      await tester.pump(const Duration(milliseconds: 300));
      final glow =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('discovery-glow-1')),
                  )
                  .decoration
              as BoxDecoration;
      expect(glow.boxShadow, isNotEmpty);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );
}
