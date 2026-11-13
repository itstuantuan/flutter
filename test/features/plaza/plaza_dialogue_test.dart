import 'dart:math';

import 'package:bots/features/plaza/plaza_dialogue.dart';
import 'package:bots/features/plaza/plaza_scenarios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all ten complete stories are reachable without adjacent repeats', () {
    expect(plazaScenarios.length, 10);
    final picker = PlazaScenarioPicker(random: Random(7));
    final first = List.generate(10, (_) => picker.next());
    expect(first.toSet().length, 10);
    expect(picker.next(), isNot(same(first.last)));
    for (final story in plazaScenarios) {
      expect(story.lines.first.speaker, isEmpty);
      expect(story.lines.first.text, startsWith('✦'));
      expect(story.lines.length, greaterThanOrEqualTo(13));
      expect(story.lines.last.speaker, isNotEmpty);
    }
    expect(plazaScenarios[3].lines[3].speaker, isEmpty);
  });

  testWidgets(
    'story plays in order, pauses offscreen and stops at its ending',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: PlazaDialogue(scenario: plazaScenarios.first),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder line(int index) => find.byKey(ValueKey('plaza-line-$index'));
      expect(line(0), findsOneWidget);
      expect(line(1), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(line(1), findsOneWidget);
      expect(line(2), findsNothing);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(line(2), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(line(2), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 2; i < plazaScenarios.first.lines.length; i++) {
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        expect(line(i), findsOneWidget);
      }
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(line(plazaScenarios.first.lines.length), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );
}
