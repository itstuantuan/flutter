import 'package:bots/features/character/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entrance completes and reduced motion disables movement', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashArtwork()));
    final fades = find.descendant(
      of: find.byType(SplashArtwork),
      matching: find.byType(Opacity),
    );
    expect(
      tester.widgetList<Opacity>(fades).any((w) => w.opacity == 0),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(
      tester.widgetList<Opacity>(fades).every((w) => w.opacity == 1),
      isTrue,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SplashArtwork(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SplashArtwork),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash assets render at design size and on a taller phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: SplashArtwork(animate: false)),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(SplashArtwork));
      await Future.wait([
        for (final layer in SplashArtwork.layers)
          precacheImage(AssetImage('assets/design/${layer.name}.png'), context),
      ]);
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SplashArtwork),
      matchesGoldenFile('goldens/splash.png'),
    );
    for (final size in [
      const Size(390, 844),
      const Size(412, 915),
      const Size(375, 667),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final art = find.descendant(
        of: find.byType(FittedBox),
        matching: find.byType(Stack),
      );
      final box = tester.renderObject<RenderBox>(art);
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      expect(topLeft.dx, lessThanOrEqualTo(0.01));
      expect(topLeft.dy, lessThanOrEqualTo(0.01));
      expect(bottomRight.dx, greaterThanOrEqualTo(size.width - 0.01));
      expect(bottomRight.dy, greaterThanOrEqualTo(size.height - 0.01));
    }
  });
}
