import 'package:bots/features/notifications/notification_prompt.dart';
import 'package:bots/features/notifications/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPromptStore extends NotificationPromptStore {
  bool shown = false;
  @override
  Future<bool> wasShown() async => shown;
  @override
  Future<void> markShown() async {
    shown = true;
  }

  @override
  Future<void> clear() async {
    shown = false;
  }
}

class FakePush extends PushService {
  int requests = 0, settings = 0;
  bool available = true;
  @override
  bool get supported => available;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> request() async {
    requests++;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }
}

Widget app(FakePush push, MemoryPromptStore store, {int key = 0}) =>
    MaterialApp(
      key: ValueKey(key),
      home: HomeNotificationPrompt(
        push: push,
        store: store,
        child: const Scaffold(body: Text('home')),
      ),
    );

void main() {
  testWidgets('declining prompts only once across home recreation', (
    tester,
  ) async {
    final push = FakePush();
    final store = MemoryPromptStore();
    await tester.pumpWidget(app(push, store));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPermissionDialog), findsOneWidget);
    expect(push.requests, 0);
    await tester.tap(find.text('不允许'));
    await tester.pumpAndSettle();
    expect(store.shown, isTrue);
    await tester.pumpWidget(app(push, store, key: 1));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPermissionDialog), findsNothing);
    expect(push.requests, 0);
  });
  testWidgets('allow requests once; previously denied opens settings', (
    tester,
  ) async {
    for (final state in ['notDetermined', 'denied']) {
      final push = FakePush()..authorization = state;
      await tester.pumpWidget(
        app(push, MemoryPromptStore(), key: state.length),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('允许'));
      await tester.pumpAndSettle();
      expect(push.requests, state == 'notDetermined' ? 1 : 0);
      expect(push.settings, state == 'denied' ? 1 : 0);
      expect(find.byType(NotificationPermissionDialog), findsNothing);
    }
  });
  testWidgets(
    'authorized, provisional, unavailable and status errors do not prompt',
    (tester) async {
      var key = 0;
      for (final push in [
        FakePush()..authorization = 'authorized',
        FakePush()..authorization = 'provisional',
        FakePush()..available = false,
        FakePush()..error = 'unavailable',
      ]) {
        final store = MemoryPromptStore();
        await tester.pumpWidget(app(push, store, key: key++));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationPermissionDialog), findsNothing);
        expect(store.shown, isFalse);
      }
    },
  );
  testWidgets('dialog fits small screens and large text', (tester) async {
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
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: const Scaffold(body: NotificationPermissionDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('允许'));
      expect(tester.takeException(), isNull);
    }
  });
}
