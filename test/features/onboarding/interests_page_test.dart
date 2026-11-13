import 'package:bots/features/onboarding/interests_page.dart';
import 'package:bots/features/auth/name_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bubbles float, stay tappable and respect reduced motion', (
    tester,
  ) async {
    Widget app(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: InterestsPage(onStart: (_) async => true),
      ),
    );
    await tester.pumpWidget(app(false));
    final motion = find.byKey(const ValueKey('interest-motion-音乐'));
    final before = tester.widget<Transform>(motion).transform.clone();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Transform>(motion).transform, isNot(before));
    await tester.tap(find.byKey(const ValueKey('interest-音乐')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('remove-音乐')), findsOneWidget);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    final still = tester.widget<Transform>(motion).transform.clone();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Transform>(motion).transform, still);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection, removal, all and retry send real unique values', (
    tester,
  ) async {
    List<String>? sent;
    bool fail = true;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: InterestsPage(
          onStart: (values) async {
            sent = values;
            return !fail;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('interests-start')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('interest-旅游')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('interests-start')));
    await tester.pumpAndSettle();
    expect(sent, ['旅游']);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('interests-all')));
    await tester.pumpAndSettle();
    expect(find.text('取消全选'), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsNothing);
    await tester.tap(find.text('取消全选'));
    await tester.pumpAndSettle();
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('-  选择0,还可以选择9个 -'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('interests-start')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('remove-旅游')));
    await tester.tap(find.byKey(const ValueKey('remove-旅游')));
    await tester.pumpAndSettle();
    expect(find.text('全选'), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const ValueKey('interests-start')));
    await tester.pumpAndSettle();
    expect(sent!.length, 8);
    expect(sent, isNot(contains('旅游')));
    expect(sent!.toSet().length, 8);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'name and interests fit short phones, landscape, large text and keyboards',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(375, 812),
        const Size(414, 736),
        const Size(320, 568),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        for (final scale in [1.0, 2.0]) {
          for (final name in [false, true]) {
            final keyboard = name ? 200.0 : 0.0;
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    viewInsets: EdgeInsets.only(bottom: keyboard),
                  ),
                  child: name
                      ? NamePage(
                          key: ValueKey('$size-$scale'),
                          onContinue: (_) async {},
                        )
                      : InterestsPage(
                          key: ValueKey('$size-$scale'),
                          initialSelection: designInterests,
                          onStart: (_) async => true,
                        ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final button = find.byKey(
              ValueKey(name ? 'name-next' : 'interests-start'),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final rect = tester.getRect(button);
            expect(rect.bottom, lessThanOrEqualTo(size.height - keyboard));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}
