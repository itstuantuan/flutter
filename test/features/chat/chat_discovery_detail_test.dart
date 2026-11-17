import 'package:bots/features/chat/chat_discovery_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('full text scrolls to its end on small screens and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(375, 812),
      const Size(320, 568),
      const Size(812, 375),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ChatDiscoveryDetail(
                card: {
                  'title': '听说唱，你更在意押韵还是表达？',
                  'content':
                      '${List.filled(40, '这是完整正文，支持上下滚动阅读。').join('\n')}正文结束',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('discovery-expanded-scroll')),
          )
          .controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, 0);
      expect(tester.takeException(), isNull);
    }
  });
}
