import 'package:bots/features/plaza/plaza_discovery.dart';
import 'package:bots/features/plaza/plaza_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('discovery pages select content and dismiss back to plaza', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlazaPage(initialDiscovery: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlazaDiscoveryDialog), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('plaza-discovery-pages')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('猫咪到底在想些什么？'), findsOneWidget);
    await tester.tap(find.text('查看内容').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(PlazaDiscoveryDialog), findsNothing);
    expect(find.text(PlazaDiscovery.samples[1].body), findsOneWidget);
    await tester.tap(find.text('返回广场'));
    await tester.pumpAndSettle();
    expect(find.byType(PlazaPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discovery card remains reachable on small screens and large text',
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
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const PlazaPage(initialDiscovery: 0),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('查看内容').first);
          await tester.tap(find.text('查看内容').hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(PlazaDiscoveryDialog), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: '$size text scale $scale',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets('barrier dismisses without opening content', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PlazaPage(initialDiscovery: 0)),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 80));
    await tester.pumpAndSettle();
    expect(find.byType(PlazaDiscoveryDialog), findsNothing);
    expect(find.byType(PlazaPage), findsOneWidget);
  });
}
