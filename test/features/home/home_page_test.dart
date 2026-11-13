import 'dart:math' as math;

import 'package:bots/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'home preserves scene width and controls across sizes and text scales',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(375, 667),
        const Size(320, 568),
        const Size(430, 932),
        const Size(812, 375),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 44, bottom: 34),
                ),
                child: HomePage(
                  onMenu: () => taps++,
                  onFriends: () => taps++,
                  onExplore: () => taps++,
                  onChat: () => taps++,
                  onVoice: () => taps++,
                  onDiscovery: (_) => taps++,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size scale $scale');
          final image = tester.getSize(find.byType(Image));
          expect(
            image.width,
            closeTo(
              math.max(
                    (size.width > 600 ? 600 : size.width) / 375,
                    size.height / 812,
                  ) *
                  413.08,
              0.001,
            ),
          );
          final chat = find.byTooltip('聊天');
          expect(
            tester.getRect(chat).bottom,
            lessThanOrEqualTo(size.height - 34),
          );
          await tester.tap(chat);
          expect(taps, 1);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'iPhone 6s Plus home fits one viewport without vertical scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(414, 736);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(414, 736),
              padding: EdgeInsets.only(top: 20),
            ),
            child: HomePage(
              onMenu: () {},
              onExplore: () {},
              onChat: () {},
              onVoice: () {},
              onDiscovery: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('home-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(tester.getRect(find.byTooltip('聊天')).bottom, lessThan(736));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('swiping discovery pages updates the action target', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final opened = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onMenu: () {},
          onExplore: () {},
          onChat: () {},
          onVoice: () {},
          onDiscovery: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var page = 0; page < 3; page++) {
      await tester.tap(find.text('去看看').hitTestable());
      expect(opened.last, page);
      if (page < 2) {
        await tester.drag(
          find.byKey(const ValueKey('home-discoveries')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
