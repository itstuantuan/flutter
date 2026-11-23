import 'package:bots/features/exploration/exploration_controller.dart';
import 'package:bots/features/exploration/live_plaza_page.dart';
import 'package:bots/features/plaza/plaza_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'ready cards present in batches and completion does not replay them',
    (tester) async {
      final service = FakeBotService();
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      await controller.initialize();
      await controller.chat.initializeSession();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final cards = (completionEvent()['cards'] as List).cast<Map>();
      void ready(int count) {
        service.progress = {
          'phase': 'searching',
          'cards': cards.take(count).toList(),
        };
      }

      ready(1);
      await tester.pumpWidget(
        MaterialApp(
          home: LivePlazaPage(
            controller: controller,
            taskId: 'task-1',
            onChat: (_) async {},
            onOpenDiscovery: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dialog = find.byType(PlazaDiscoveryDialog);
      Iterable<String?> materials() => tester
          .widget<PlazaDiscoveryDialog>(dialog)
          .discoveries
          .map((c) => c.materialId);
      expect(materials(), ['material-1']);
      ready(3);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(materials(), ['material-1']);
      controller.receiveCompletion(completionEvent());
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(materials(), ['material-2', 'material-3']);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(controller.pendingEvents, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );

  testWidgets(
    'bubble follows server elapsed time, connection errors and completion',
    (tester) async {
      final service = FakeBotService();
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      )..pause();
      await controller.initialize();
      controller.resume();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: LivePlazaPage(
            controller: controller,
            taskId: 'task-1',
            onChat: (_) async {},
            onOpenDiscovery: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pal 努力探索中'), findsOneWidget);
      expect(find.text('已探索 12 秒 · 发现后告诉你'), findsOneWidget);
      service.square = {'elapsedSeconds': 65};
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('已探索 1 分 5 秒'), findsOneWidget);
      service.failProgress = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('正在同步探索状态'), findsOneWidget);
      service.failProgress = false;
      service.progress = {
        'phase': 'complete',
        'cards': completionEvent()['cards'],
      };
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Pal 带着发现回来啦'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      final polls = service.calls
          .where((c) => (c['path'] as String).endsWith('/progress'))
          .length;
      await tester.pump(const Duration(seconds: 6));
      expect(
        service.calls
            .where((c) => (c['path'] as String).endsWith('/progress'))
            .length,
        polls,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );

  testWidgets(
    'completion automatically presents once and acknowledges after display',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <(String, String?)>[];
      final service = FakeBotService();
      final store = MemoryExplorationStore();
      final controller = ExplorationController(
        service: service,
        store: store,
        displayName: '测试',
      );
      await controller.initialize();
      await controller.chat.initializeSession();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: LivePlazaPage(
            controller: controller,
            taskId: 'task-1',
            onChat: (_) async {},
            onOpenDiscovery: (task, material) async {
              opened.add((task, material));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlazaDiscoveryDialog), findsNothing);
      controller.receiveCompletion({
        ...completionEvent(),
        'cards': [
          for (var i = 1; i <= 5; i++)
            {'materialId': 'material-$i', 'title': '发现$i', 'summary': '摘要$i'},
        ],
      });
      expect(controller.pendingEvents, hasLength(1));
      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(store.value['displayed'], isNull);
      await tester.pumpAndSettle();
      expect(find.byType(PlazaDiscoveryDialog), findsOneWidget);
      expect(
        tester
            .widget<PlazaDiscoveryDialog>(find.byType(PlazaDiscoveryDialog))
            .discoveries,
        hasLength(3),
      );
      expect(find.text('发现1'), findsOneWidget);
      expect(store.value['displayed'], ['task-1']);
      expect(
        service.calls.where(
          (call) =>
              call['method'] == 'PUT' &&
              call['path'] == '/explorations/task-1/acknowledgement',
        ),
        hasLength(1),
      );
      await tester.tapAt(const Offset(10, 80));
      await tester.pumpAndSettle();
      controller.receiveCompletion(completionEvent());
      await tester.pumpAndSettle();
      expect(find.byType(PlazaDiscoveryDialog), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plaza-discovery-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('发现1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );

  testWidgets(
    'character reopens real task results and never substitutes samples',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <(String, String?)>[];
      final service = FakeBotService();
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LivePlazaPage(
            controller: controller,
            taskId: 'task-1',
            onChat: (_) async {},
            onOpenDiscovery: (task, material) async {
              opened.add((task, material));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final trigger = find.byKey(const ValueKey('plaza-discovery-trigger'));
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(PlazaDiscoveryDialog), findsNothing);
      expect(find.text('当前探索暂无返回内容，请稍后再试'), findsOneWidget);
      service.progress = {
        'phase': 'complete',
        'cards': completionEvent()['cards'],
      };
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('发现1'), findsOneWidget);
      expect(find.text('听说唱，你更在意押韵还是表达？'), findsNothing);
      await tester.tap(find.text('查看内容').hitTestable());
      await tester.pumpAndSettle();
      expect(opened, [('task-1', 'material-1')]);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('发现1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await service.events.close();
    },
  );
}
