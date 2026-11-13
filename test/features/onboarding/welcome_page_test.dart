import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'next is reachable on short and tall phones and respects busy state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      for (final size in [
        const Size(375, 812),
        const Size(390, 844),
        const Size(320, 568),
        const Size(375, 667),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(home: WelcomePage(onNext: () => taps++)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final buttonRect = tester.getRect(find.byType(FilledButton));
        expect(buttonRect.top, greaterThanOrEqualTo(0));
        expect(buttonRect.bottom, lessThanOrEqualTo(size.height - 34));
        expect(buttonRect.height, greaterThanOrEqualTo(48));
        await tester.tap(find.byType(FilledButton));
        expect(tester.takeException(), isNull);
      }
      expect(taps, 5);
      await tester.pumpWidget(
        MaterialApp(home: WelcomePage(onNext: () => taps++, busy: true)),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets('avatars and rings animate, reduced motion stays still', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: WelcomePage(onNext: () {})));
    final avatar = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.endsWith('avatar_purple.png'),
    );
    final first = tester.getTopLeft(avatar);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.getTopLeft(avatar), isNot(first));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: WelcomePage(onNext: () {}),
        ),
      ),
    );
    await tester.pump();
    final still = tester.getTopLeft(avatar);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(avatar), still);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
