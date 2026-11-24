import 'package:bots/features/discoveries/discovery_detail_page.dart';
import 'package:bots/features/exploration/exploration_controller.dart';
import 'package:bots/features/exploration/live_plaza_page.dart';
import 'package:bots/features/plaza/plaza_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'view opens the selected plaza card detail and returns to plaza',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeBotService();
      final cards = (discoveryTurn()['exploration'] as Map)['cards'] as List;
      service.progress = {'phase': 'complete', 'cards': cards};
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => LivePlazaPage(
              controller: controller,
              taskId: 'task-1',
              onChat: (_) async {},
              onOpenDiscovery: (card) async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DiscoveryDetailPage(card: card),
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
      await tester.pumpAndSettle();
      final detail = tester.widget<DiscoveryDetailPage>(
        find.byType(DiscoveryDetailPage),
      );
      expect(detail.card, {
        ...Map<String, dynamic>.from(cards[1] as Map),
        'taskId': 'task-1',
      });
      expect(detail.card['materialId'], 'material-2');
      expect(find.byType(PlazaDiscoveryDialog), findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(LivePlazaPage), findsOneWidget);
      expect(find.byType(DiscoveryDetailPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );
}
