import 'package:bots/features/home/home_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'sidebar adapts to viewport and text scale and routes all entries',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(375, 812),
        const Size(320, 568),
        const Size(812, 375),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          String? selected;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 44, bottom: 34),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: HomeSidebar(
                    name: '名字最多七个字',
                    unreadCount: 100,
                    onSelect: (id) => selected = id,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('99+'), findsOneWidget);
          await tester.ensureVisible(find.text('系统通知'));
          await tester.tap(find.text('系统通知'));
          expect(selected, 'notifications');
          expect(find.text('调试工具'), findsNothing);
        }
      }
    },
  );
}
