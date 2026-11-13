import 'package:bots/features/onboarding/onboarding_preview_page.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'both pages share pinned controls across phone sizes and safe areas',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(390, 844),
        const Size(320, 568),
        const Size(375, 667),
        const Size(430, 932),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        Rect? firstButton;
        for (var page = 0; page < 2; page++) {
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: page == 0
                    ? WelcomePage(onNext: () => taps++)
                    : WorldPage(onNext: () => taps++),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          final button = tester.getRect(find.byType(FilledButton));
          expect(button.top, greaterThan(0));
          expect(button.bottom, lessThanOrEqualTo(size.height - 34));
          expect(button.height, 56);
          if (firstButton == null) {
            firstButton = button;
          } else {
            expect(button, firstButton);
          }
          if (page == 1) {
            final scene = find.image(
              const AssetImage('assets/design/world_scene.png'),
            );
            final expectedWidth = (size.width > 600 ? 600 : size.width) - 48;
            final renderBox = tester.renderObject<RenderBox>(scene);
            final left = renderBox.localToGlobal(Offset.zero);
            final right = renderBox.localToGlobal(
              Offset(renderBox.size.width, 0),
            );
            expect(right.dx - left.dx, closeTo(expectedWidth, 0.01));
            final characters = find.image(
              const AssetImage('assets/design/world_characters.png'),
            );
            await Scrollable.ensureVisible(
              tester.element(characters),
              alignment: 1,
            );
            await tester.pump();
            final characterBox = tester.renderObject<RenderBox>(characters);
            final characterBottom = characterBox
                .localToGlobal(characterBox.size.bottomRight(Offset.zero))
                .dy;
            expect(characterBottom, lessThanOrEqualTo(button.top - 13));
          }
          await tester.tap(find.byType(FilledButton));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'preview advances both the page and selected indicator before exiting',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingPreviewPage(),
                  ),
                ),
                child: const Text('preview'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/onboarding/indicator.png')),
        findsOneWidget,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(WorldPage), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/onboarding/world_indicator.png')),
        findsOneWidget,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('preview'), findsOneWidget);
      expect(find.byType(WorldPage), findsNothing);
    },
  );
  testWidgets('large text wraps without overlap and keeps next visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in [0, 1]) {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              padding: EdgeInsets.only(top: 44, bottom: 34),
              textScaler: TextScaler.linear(2),
            ),
            child: page == 0
                ? WelcomePage(onNext: () => taps++)
                : WorldPage(onNext: () => taps++),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.top, greaterThan(44));
      expect(button.bottom, lessThanOrEqualTo(534));
      expect(button.height, greaterThanOrEqualTo(58));
      final title = find.text(page == 0 ? '遇见懂你的TA,' : '探索世界，');
      final subtitle = find.text(page == 0 ? '开启专属陪伴' : '不止于眼前。');
      expect(
        tester.getRect(subtitle).top,
        greaterThan(tester.getRect(title).bottom),
      );
      if (page == 1) {
        final characters = find.image(
          const AssetImage('assets/design/world_characters.png'),
        );
        final lastMessage = find.text('嘿嘿，那奖励你一个摸摸头～');
        expect(
          tester.getRect(characters).top,
          greaterThan(tester.getRect(lastMessage).bottom),
        );
        await Scrollable.ensureVisible(
          tester.element(characters),
          alignment: 1,
        );
      } else {
        await Scrollable.ensureVisible(
          tester.element(find.text('来啦~欢迎小宝加入')),
          alignment: 1,
        );
      }
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
