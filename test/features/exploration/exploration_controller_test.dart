import 'dart:async';
import 'dart:convert';

import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/exploration/exploration_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('cached cards restore offline, refresh, and survive restart', () async {
    final service = FakeBotService();
    final store = MemoryExplorationStore()
      ..value = {
        'cards': [
          {'taskId': 'cached', 'title': '上次发现'},
        ],
      };
    final controller = ExplorationController(
      service: service,
      store: store,
      displayName: '测试',
    )..pause();
    await controller.initialize();
    expect(controller.cards.single['taskId'], 'cached');
    expect(controller.loadingCards, isFalse);
    expect(service.calls, isEmpty);
    service.homeCards = [
      {'taskId': 'fresh', 'title': '新发现'},
    ];
    await controller.refreshHome();
    await flush();
    expect(controller.cards.single['taskId'], 'fresh');
    expect((store.value['cards'] as List).single['taskId'], 'fresh');
    controller.acceptHome({'cards': []});
    await flush();
    expect(controller.cards.single['taskId'], 'fresh');
    controller.dispose();
    final restored = ExplorationController(
      service: service,
      store: store,
      displayName: '测试',
    )..pause();
    await restored.initialize();
    expect(restored.cards.single['taskId'], 'fresh');
    restored.dispose();
    await service.events.close();
  });

  test(
    'first load finishes its placeholder when no discovery exists',
    () async {
      final service = FakeBotService();
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      expect(controller.loadingCards, isTrue);
      await controller.initialize();
      await flush();
      expect(controller.loadingCards, isFalse);
      expect(controller.cards, isEmpty);
      controller.dispose();
      await service.events.close();
    },
  );

  test(
    'REST and SSE completions share dedupe; no ack until actually displayed',
    () async {
      final service = FakeBotService()..completions = [completionEvent()];
      final store = MemoryExplorationStore();
      final controller = ExplorationController(
        service: service,
        store: store,
        displayName: '测试',
      );
      await controller.initialize();
      await flush();
      service.events.add(
        SseEvent('exploration_completed', jsonEncode(completionEvent())),
      );
      await flush();
      expect(controller.pendingEvents, hasLength(1));
      expect(
        controller.chat.messages,
        isEmpty,
      ); // Completion must never fabricate a chat turn.
      expect(
        service.calls.where(
          (c) => (c['path'] as String).endsWith('/acknowledgement'),
        ),
        isEmpty,
      );
      service.failAck = true;
      await controller.markDisplayed(completionEvent());
      expect(store.value['displayed'], ['task-1']);
      expect(store.value['pendingAcks'], {'task-1': 'task-1'});
      controller.receiveCompletion(completionEvent());
      await flush();
      expect(controller.pendingEvents, isEmpty);
      expect(
        (await controller.discoveryResult('task-1'))?['cards'],
        completionEvent()['cards'],
      );
      expect(await controller.discoveryResult('task-2'), isNull);
      service.failAck = false;
      await controller.retryAcknowledgements();
      expect(store.value['pendingAcks'], isEmpty);
      controller.dispose();
      await service.events.close();
    },
  );

  test('failed storage cannot acknowledge or lose a completion', () async {
    final service = FakeBotService();
    final store = MemoryExplorationStore();
    final controller = ExplorationController(
      service: service,
      store: store,
      displayName: '测试',
    );
    await controller.initialize();
    await flush();
    controller.receiveCompletion(completionEvent());
    store.fail = true;
    await expectLater(
      controller.markDisplayed(completionEvent()),
      throwsStateError,
    );
    expect(controller.pendingEvents, hasLength(1));
    expect(
      service.calls.where(
        (c) => (c['path'] as String).endsWith('/acknowledgement'),
      ),
      isEmpty,
    );
    controller.dispose();
    await service.events.close();
  });

  test(
    'new exploration retains persisted ID on timeout and restores active task',
    () async {
      final service = FakeBotService()
        ..timeoutStart = true
        ..selectedInterests = ['music', 'games'];
      final store = MemoryExplorationStore();
      final controller = ExplorationController(
        service: service,
        store: store,
        displayName: '测试',
      );
      await controller.initialize();
      await flush();
      expect(await controller.startExploration(), isNull);
      final original = store.value['pendingStartId'];
      service.timeoutStart = false;
      expect(await controller.startExploration(), 'task-1');
      final posts = service.calls.where((c) => c['method'] == 'POST').toList();
      expect((posts.first['data'] as Map)['clientMessageId'], original);
      expect((posts.last['data'] as Map)['clientMessageId'], original);
      expect((posts.first['data'] as Map)['tags'], ['music', 'games']);
      expect((posts.last['data'] as Map)['tags'], ['music', 'games']);
      expect(await controller.startExploration(), 'task-1');
      expect(service.starts, 2);
      expect(controller.chat.messages, isEmpty);
      controller.dispose();
      await service.events.close();
    },
  );

  test(
    'empty home restores previous published discovery from server history',
    () async {
      final service = FakeBotService()
        ..historyItems = [
          {'status': 'completed', 'taskId': 'yesterday'},
        ]
        ..progress = {'phase': 'complete', 'cards': completionEvent()['cards']}
        ..located = {'anchorTurnId': 42};
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      await controller.initialize();
      await flush();
      await flush();
      expect(controller.cards, hasLength(3));
      expect(controller.cards.first['taskId'], 'yesterday');
      expect(
        service.calls.where((c) => (c['path'] as String).contains('/locate/')),
        isEmpty,
      );
      controller.acceptHome({'cards': [], 'activeExploration': null});
      expect(controller.cards, hasLength(3));
      service.homeCards = [
        {'title': 'new', 'taskId': 'new-task'},
      ];
      controller.acceptHome({'cards': service.homeCards});
      await flush();
      expect(controller.cards.single['taskId'], 'new-task');
      controller.dispose();
      await service.events.close();
    },
  );

  test(
    'locate uses original exploration ID and preserves one backend discovery',
    () async {
      final service = FakeBotService()
        ..located = {
          'anchorTurnId': 42,
          'turns': [discoveryTurn()],
        };
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      );
      await controller.initialize();
      await flush();
      expect(
        await controller.chat.locate('task-1', materialId: 'material-2'),
        isTrue,
      );
      expect(controller.chat.anchorTurnId, 42);
      expect(controller.chat.messages, hasLength(1));
      expect(controller.chat.messages.single.cards, hasLength(3));
      expect(await controller.chat.send('这个发现详细说说'), isTrue);
      final sent =
          service.calls.lastWhere((c) => c['method'] == 'POST')['data'] as Map;
      expect(sent['referenceTaskId'], 'task-1');
      expect(sent['referenceMaterialId'], 'material-2');
      controller.dispose();
      await service.events.close();
    },
  );
  test(
    'recovering a task after a lost receipt clears the previous operation ID',
    () async {
      final service = FakeBotService()..timeoutStart = true;
      final store = MemoryExplorationStore();
      final controller = ExplorationController(
        service: service,
        store: store,
        displayName: '测试',
      );
      await controller.initialize();
      await flush();
      await controller.startExploration();
      final oldId = store.value['pendingStartId'];
      service.activeTask = 'accepted-without-receipt';
      expect(await controller.startExploration(), 'accepted-without-receipt');
      expect(store.value['pendingStartId'], isNull);
      service.activeTask = null;
      service.timeoutStart = false;
      await controller.startExploration();
      final last =
          service.calls.lastWhere((c) => c['method'] == 'POST')['data'] as Map;
      expect(last['clientMessageId'], isNot(oldId));
      controller.dispose();
      await service.events.close();
    },
  );
  test('departure reads home and interests once and uses confirmed selection without rereading', () async {
    final service = FakeBotService();
    final controller = ExplorationController(
      service: service,
      store: MemoryExplorationStore(),
      displayName: '测试',
    )..pause();
    await controller.initialize();
    var confirmations = 0;
    expect(
      await controller.startExploration(
        confirmInterests: (selection) async {
          confirmations++;
          expect(selection['selected'], ['music']);
          await controller.saveInterests(['游戏']);
          return ['games'];
        },
      ),
      'task-1',
    );
    expect(confirmations, 1);
    expect(service.calls.where((c) => c['path'] == '/home'), hasLength(1));
    expect(
      service.calls.where(
        (c) => c['path'] == '/me/interests' && c['method'] == 'GET',
      ),
      hasLength(1),
    );
    expect(
      service.calls.where((c) => c['method'] == 'POST').single['data'],
      containsPair('tags', ['games']),
    );
    controller.dispose();
    await service.events.close();
  });
  test(
    'cancelled interest selection or leaving route never starts exploration',
    () async {
      final service = FakeBotService();
      final controller = ExplorationController(
        service: service,
        store: MemoryExplorationStore(),
        displayName: '测试',
      )..pause();
      await controller.initialize();
      expect(
        await controller.startExploration(confirmInterests: (_) async => null),
        isNull,
      );
      expect(service.starts, 0);
      expect(await controller.startExploration(isCurrent: () => false), isNull);
      expect(service.starts, 0);
      controller.dispose();
      await service.events.close();
    },
  );
  test('startup and departure share an in-flight home request', () async {
    final gate = Completer<void>();
    final service = FakeBotService()
      ..homeGate = gate
      ..confirmed = true;
    final controller = ExplorationController(
      service: service,
      store: MemoryExplorationStore(),
      displayName: '测试',
    );
    await controller.initialize();
    await flush();
    final departure = controller.startExploration();
    await flush();
    expect(service.calls.where((c) => c['path'] == '/home'), hasLength(1));
    gate.complete();
    expect(await departure, 'task-1');
    expect(service.calls.where((c) => c['path'] == '/home'), hasLength(1));
    expect(
      service.calls.where(
        (c) => c['path'] == '/me/interests' && c['method'] == 'GET',
      ),
      hasLength(1),
    );
    controller.dispose();
    await service.events.close();
  });
}
