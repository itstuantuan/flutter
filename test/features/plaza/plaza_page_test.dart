import 'package:bots/features/plaza/plaza_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plaza chat and microphone invoke their distinct actions', (
    tester,
  ) async {
    var chats = 0, voices = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlazaPage(onChat: () => chats++, onVoice: () => voices++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('广场聊天'));
    expect(chats, 1);
    expect(voices, 0);
    await tester.tap(find.byTooltip('广场语音'));
    expect(chats, 1);
    expect(voices, 1);
    expect(find.byTooltip('广场更多'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'plaza fits short and tall phones without scrolling at normal text size',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(414, 736), const Size(430, 932)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: EdgeInsets.only(
                  top: size.height < 800 ? 20 : 59,
                  bottom: size.height < 800 ? 0 : 34,
                ),
              ),
              child: const PlazaPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('plaza-content')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scroll.position.maxScrollExtent, 0, reason: '$size');
        final last = tester.getRect(
          find.textContaining('✦', findRichText: true),
        );
        expect(last.bottom, lessThanOrEqualTo(size.height - 57));
        expect(
          last.top,
          greaterThan(tester.getRect(find.byTooltip('返回首页')).bottom),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'plaza transcript scrolls while header actions remain reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(320, 568),
        const Size(430, 932),
        const Size(812, 375),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 44, bottom: 34),
                ),
                child: const PlazaPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final backRect = tester.getRect(find.byTooltip('返回首页'));
          expect(backRect.top, greaterThanOrEqualTo(44));
          expect(backRect.bottom, lessThan(size.height - 34));
          await Scrollable.ensureVisible(
            tester.element(find.textContaining('✦', findRichText: true)),
            alignment: 1,
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.textContaining('✦', findRichText: true)).bottom,
            lessThanOrEqualTo(size.height + 0.01),
          );
          expect(find.byTooltip('广场更多'), findsNothing);
          expect(
            tester.getRect(find.byTooltip('广场聊天')).bottom,
            lessThanOrEqualTo(size.height - 34),
          );
          expect(find.byTooltip('广场语音'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$size text $scale');
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
