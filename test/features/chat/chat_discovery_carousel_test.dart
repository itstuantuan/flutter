import 'package:bots/features/chat/chat_discovery_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cards = [
    {
      'materialId': 'one',
      'title': '第一条发现',
      'summary': '卡片摘要',
      'content': '第一条的完整正文',
    },
    {'materialId': 'two', 'title': '第二条发现', 'content': '没有摘要时使用正文'},
    {'materialId': 'three', 'title': '第三条发现', 'summary': '最后一条摘要'},
  ];

  testWidgets('swipes discoveries and opens the full published content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ChatDiscoveryCarousel(cards: cards),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一条发现'));
    await tester.pumpAndSettle();
    expect(find.text('第一条的完整正文'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.tap(find.text('第二条发现'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      '没有摘要时使用正文',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps selected discovery across resizing and supports large text',
    (tester) async {
      final key = GlobalKey<ChatDiscoveryCarouselState>();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(320, 568),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ChatDiscoveryCarousel(key: key, cards: cards),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final reveal = key.currentState!.revealMaterial('three');
        await tester.pumpAndSettle();
        await reveal;
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          2,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'pagination tracks swipes and retains material identity on reorder',
    (tester) async {
      final key = GlobalKey<ChatDiscoveryCarouselState>();
      Widget page(List<Map<String, dynamic>> data) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ChatDiscoveryCarousel(
                key: key,
                cards: data,
                animate: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(cards));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discovery-page-2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      await tester.pumpWidget(page([cards[2], cards[0], cards[1]]));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      await tester.pumpWidget(page([cards[0]]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-page-0')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('location glow is finite and disabled for reduced motion', (
    tester,
  ) async {
    final pulse = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 2400),
    );
    addTearDown(pulse.dispose);
    Widget page(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ChatDiscoveryCarousel(
                cards: cards,
                highlightedMaterialId: 'one',
                focusAnimation: pulse,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    pulse.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    BoxDecoration glow() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('discovery-glow-0')),
                )
                .decoration
            as BoxDecoration;
    expect(glow().boxShadow, isNotEmpty);
    await tester.pumpWidget(page(true));
    expect(glow().boxShadow, isEmpty);
    await tester.pumpAndSettle();
    expect(pulse.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
