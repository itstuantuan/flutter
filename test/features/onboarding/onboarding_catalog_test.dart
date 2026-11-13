import 'dart:async';

import 'package:bots/features/onboarding/onboarding_flow.dart';
import 'package:bots/features/onboarding/onboarding_page.dart';
import 'package:bots/features/onboarding/onboarding_pages.dart';
import 'package:bots/features/onboarding/onboarding_preview_page.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OnboardingPageDefinition page(String id) => OnboardingPageDefinition(
  id: id,
  nextLabel: '下一步 $id',
  builder: (onNext, busy, error) =>
      WelcomePage(onNext: onNext, busy: busy, error: error),
);

void main() {
  testWidgets('three pages follow catalog order, count and completion', (
    tester,
  ) async {
    final saved = <String?>[];
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          pages: [page('third'), page('first'), page('second')],
          onAdvance: (id) async {
            saved.add(id);
            return true;
          },
          onComplete: () => completed++,
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      expect(
        find.text('下一步 ${['third', 'first', 'second'][i]}'),
        findsOneWidget,
      );
      final scope = tester.widget<OnboardingPageScope>(
        find.byType(OnboardingPageScope),
      );
      expect(scope.index, i);
      expect(scope.count, 3);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == '引导，第 ${i + 1} 页，共 3 页',
        ),
        findsOneWidget,
      );
      expect(completed, 0);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
    }
    expect(saved, ['first', 'second', null]);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'stable ID survives reordering; removed IDs fall back to first page',
    (tester) async {
      Widget app(List<OnboardingPageDefinition> pages) => MaterialApp(
        home: OnboardingFlow(
          pages: pages,
          initialPageId: 'second',
          onComplete: () {},
        ),
      );
      await tester.pumpWidget(
        app([page('first'), page('second'), page('third')]),
      );
      expect(find.text('下一步 second'), findsOneWidget);
      await tester.pumpWidget(
        app([page('second'), page('third'), page('first')]),
      );
      expect(find.text('下一步 second'), findsOneWidget);
      expect(
        tester
            .widget<OnboardingPageScope>(find.byType(OnboardingPageScope))
            .index,
        0,
      );
      await tester.pumpWidget(app([page('third'), page('first')]));
      expect(find.text('下一步 third'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed save stays on page and repeated taps do not skip pages', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          pages: [page('first'), page('second'), page('third')],
          onAdvance: (_) {
            calls++;
            return pending.future;
          },
          onComplete: () {},
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    pending.complete(false);
    await tester.pump();
    expect(find.text('下一步 first'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('preview uses the same catalog without saving progress', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPreviewPage()));
    final flow = tester.widget<OnboardingFlow>(find.byType(OnboardingFlow));
    expect(flow.pages.map((p) => p.id), onboardingPages.map((p) => p.id));
    expect(flow.onAdvance, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('rejects empty catalogs and duplicate IDs', () {
    expect(
      () => OnboardingFlow(pages: [], onComplete: () {}),
      throwsArgumentError,
    );
    expect(
      () => OnboardingFlow(
        pages: [page('same'), page('same')],
        onComplete: () {},
      ),
      throwsArgumentError,
    );
  });
}
