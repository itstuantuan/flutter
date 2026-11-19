import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/shared/design_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'explore starts beside the chat toolbar and drags without a long press',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            onMenu: () {},
            onExplore: () => opened++,
            onChat: () {},
            onVoice: () {},
            onDiscovery: (_) {},
          ),
        ),
      );
      await tester.pump();
      final banner = find.byKey(const ValueKey('home-explore-banner'));
      expect(tester.getRect(banner).left, 0);
      expect(tester.getSize(banner).width, 130);
      final start = tester.getCenter(banner);
      expect(start.dy, closeTo(tester.getCenter(find.byTooltip('聊天')).dy, 2));
      final gesture = await tester.startGesture(tester.getCenter(banner));
      await gesture.moveBy(const Offset(16, -70));
      await gesture.moveBy(const Offset(10, -60));
      await tester.pump();
      expect(tester.getRect(banner).left, 0);
      expect(tester.getCenter(banner).dy, start.dy - 130);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(tester.getCenter(banner).dy, start.dy - 100);
      await gesture.up();
      expect(opened, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('iPhone 17 Pro keeps sky behind the status bar with tall cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);

    const boundary = ValueKey('iphone-17-pro-home');
    Widget page(List<HomeDiscovery> cards) => MaterialApp(
      home: RepaintBoundary(
        key: boundary,
        child: HomePage(
          discoveries: cards,
          onMenu: () {},
          onExplore: () {},
          onChat: () {},
          onVoice: () {},
          onDiscovery: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(page(const []));
    final scene = find.byType(DesignScene);
    final initialImageTop = tester.getTopLeft(find.byType(Image).first).dy;
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/design/home_raw.png'),
        tester.element(scene),
      );
    });
    const title = '1998年深圳歌舞厅起步，曾毅\n曾是维修工转音乐总监';
    for (final (cardTitle, expectedOffset) in [
      (title, 67.0),
      ('$title\n还有更多故事', 98.0),
    ]) {
      await tester.pumpWidget(
        page([
          HomeDiscovery(
            description: '这个发现里有些有意思的细节，想\n带回来和你聊聊',
            title: cardTitle,
            style: DiscoveryStyle.purple,
          ),
        ]),
      );
      await tester.pump();

      final sceneOffset = tester.widget<DesignScene>(scene).topExtension;
      expect(sceneOffset, closeTo(expectedOffset, 1));
      expect(
        tester.getTopLeft(find.byType(Image).first).dy,
        closeTo(initialImageTop + sceneOffset, 0.001),
      );
      expect(tester.getTopLeft(find.byTooltip('菜单')).dy, greaterThan(62));

      final paint = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final image = paint.toImageSync();
      final pixels = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      image.dispose();
      for (final y in [0, 30, 61]) {
        final offset = (y * 402 + 201) * 4;
        expect(pixels!.getUint32(offset), isNot(0x18191EFF), reason: 'row $y');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('magnifier reopens, collapses again, and a still press enters', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onMenu: () {},
          onExplore: () => opened++,
          onChat: () {},
          onVoice: () {},
          onDiscovery: (_) {},
        ),
      ),
    );
    final banner = find.byKey(const ValueKey('home-explore-banner'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(banner).width, 68);

    final start = tester.getRect(banner).top;
    await tester.drag(banner, const Offset(0, -50));
    await tester.pump();
    expect(tester.getRect(banner).top, start - 50);
    expect(tester.getSize(banner).width, 68);
    expect(opened, 0);

    await tester.tap(banner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(banner).width, 130);
    expect(opened, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(banner).width, 68);

    await tester.tap(banner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final hold = await tester.startGesture(tester.getCenter(banner));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.getSize(banner).width, 130);
    expect(opened, 0);
    await hold.up();
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('first load shows a noninteractive placeholder then real cards', (
    tester,
  ) async {
    Widget page({required bool loading, required List<HomeDiscovery> cards}) =>
        MaterialApp(
          home: HomePage(
            onMenu: () {},
            onExplore: () {},
            onChat: () {},
            onVoice: () {},
            onDiscovery: (_) {},
            loadingDiscoveries: loading,
            discoveries: cards,
          ),
        );
    await tester.pumpWidget(page(loading: true, cards: []));
    expect(
      find.byKey(const ValueKey('home-discoveries-loading')),
      findsOneWidget,
    );
    expect(find.text('去看看'), findsNothing);
    await tester.pumpWidget(
      page(loading: true, cards: HomePage.designDiscoveries),
    );
    expect(
      find.byKey(const ValueKey('home-discoveries-loading')),
      findsNothing,
    );
    expect(find.text('去看看'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: '$size scale $scale');
          final image = tester.getSize(find.byType(Image).first);
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var page = 0; page < 3; page++) {
      await tester.tap(find.text('去看看').hitTestable());
      expect(opened.last, page);
      if (page < 2) {
        await tester.drag(
          find.byKey(const ValueKey('home-discoveries')),
          const Offset(-300, 0),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
