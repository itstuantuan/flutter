import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bots/core/localization/app_localizations.dart';
import 'package:bots/features/plaza/plaza_scenarios.dart';
import 'package:bots/features/plaza/plaza_dialogue.dart';
import 'package:bots/features/plaza/plaza_progress_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all built-in plaza stories and speakers have English copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppTranslations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) {
            for (final scenario in plazaScenarios) {
              for (final copy in [
                scenario.title,
                for (final line in scenario.lines) ...[line.speaker, line.text],
              ]) {
                expect(
                  RegExp(r'[\u4e00-\u9fff]').hasMatch(translate(context, copy)),
                  isFalse,
                  reason: copy,
                );
              }
            }
            expect(
              translate(context, '已探索 12 秒 · 发现后告诉你'),
              'Exploring for 12s · Updates soon',
            );
            expect(translate(context, '已探索 2 分 3 秒'), 'Exploring for 2m 3s');
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets(
    'plaza dialogue and progress respond to language without restarting story',
    (tester) async {
      final locale = ValueNotifier(const Locale('en'));
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppTranslations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Column(
                children: [
                  AppText(plazaScenarios[1].title),
                  const SizedBox(
                    width: 220,
                    child: PlazaProgressBubble(phase: 'complete'),
                  ),
                  Expanded(child: PlazaDialogue(scenario: plazaScenarios[1])),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The Flower Shop Resignation'), findsOneWidget);
      expect(find.text('Pal has new discoveries!'), findsOneWidget);
      expect(find.text('Tap to see what I found'), findsOneWidget);
      expect(
        find.text('Customer: Why is it quitting?', findRichText: true),
        findsOneWidget,
      );
      locale.value = const Locale('zh');
      await tester.pump();
      await tester.pump();
      expect(find.text('花店的离职申请'), findsOneWidget);
      expect(find.text('Pal 带着发现回来啦'), findsOneWidget);
      expect(find.text('顾客: 它为什么辞职？', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      locale.dispose();
    },
  );
}
