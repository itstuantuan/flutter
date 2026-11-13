import 'package:bots/features/experience/experience_controller.dart';
import 'package:bots/features/experience/experience_page.dart';
import 'package:bots/features/experience/experience_store.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/plaza/plaza_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements ExperienceStore {
  Map<String, dynamic>? data;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('failed');
    data = value;
  }
}

void main() {
  testWidgets(
    'first run persists both steps; failed saves stay on the current page',
    (tester) async {
      final store = _MemoryStore();
      final flow = ExperienceController(store);
      await tester.pumpWidget(
        MaterialApp(
          home: ExperiencePage(controller: flow, previewWelcomeOnStart: false),
        ),
      );
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      store.fail = true;
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      store.fail = false;
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WorldPage), findsOneWidget);
      expect(store.data?['step'], 'world');
      store.fail = true;
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WorldPage), findsOneWidget);
      store.fail = false;
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(store.data?['step'], 'name');
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );

  testWidgets(
    'registered users skip onboarding even with old welcome progress',
    (tester) async {
      final flow = ExperienceController(_MemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          home: ExperiencePage(
            controller: flow,
            registrationCompleted: true,
            previewWelcomeOnStart: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.byType(WorldPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );

  testWidgets(
    'unregistered users see introductions again after a fresh launch',
    (tester) async {
      final store = _MemoryStore()
        ..data = {'step': 'home', 'onboardingCompleted': true};
      for (var launch = 0; launch < 2; launch++) {
        final flow = ExperienceController(store);
        await tester.pumpWidget(
          MaterialApp(
            home: ExperiencePage(
              controller: flow,
              registrationCompleted: false,
              previewWelcomeOnStart: true,
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(WelcomePage), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(find.byType(WorldPage), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(find.byType(HomePage), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        flow.dispose();
      }
    },
  );

  testWidgets(
    'debug review shows both pages and preserves returning user progress',
    (tester) async {
      final store = _MemoryStore()..data = {'step': 'name', 'name': '小明'};
      final flow = ExperienceController(store);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: ExperiencePage(controller: flow, previewWelcomeOnStart: true),
        ),
      );
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WorldPage), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WorldPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      await tester.tap(find.text('去看看').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(PlazaPage), findsOneWidget);
      await tester.tap(find.byTooltip('返回首页'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      await tester.tap(find.byTooltip('菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('流程验证'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsNothing);
      await tester.tap(find.byTooltip('返回首页'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      await tester.tap(find.byTooltip('聊天'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '今天想听音乐');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(flow.messages, contains('你：今天想听音乐'));
      expect(store.data?['step'], 'name');
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );
}
