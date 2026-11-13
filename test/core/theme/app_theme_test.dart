import 'dart:ui' as ui;

import 'package:bots/core/theme/app_theme.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real home and onboarding controls do not paint a pressed overlay',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var taps = 0;
      const canvasKey = ValueKey('interaction-canvas');
      Future<List<int>> pixels() async => (await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(canvasKey),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!.buffer.asUint8List().toList();
      }))!;
      for (final onboarding in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            // Freeze decorative motion when comparing pressed-state pixels.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: RepaintBoundary(
              key: canvasKey,
              child: onboarding
                  ? WorldPage(onNext: () => taps++)
                  : HomePage(
                      onMenu: () => taps++,
                      onExplore: () => taps++,
                      onChat: () => taps++,
                      onVoice: () => taps++,
                      onDiscovery: (_) => taps++,
                    ),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final img in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(
              img.image,
              tester.element(find.byType(Scaffold)),
            );
          }
        });
        await tester.pumpAndSettle();
        for (final target
            in onboarding
                ? [find.byType(FilledButton)]
                : [find.text('去看看').hitTestable(), find.byTooltip('聊天')]) {
          final before = await pixels();
          final beforeTaps = taps;
          final gesture = await tester.startGesture(tester.getCenter(target));
          await tester.pump(const Duration(milliseconds: 180));
          expect(
            await pixels(),
            orderedEquals(before),
            reason: 'pressing must not add a ripple, highlight or shadow',
          );
          expect(taps, beforeTaps);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(taps, beforeTaps + 1);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
