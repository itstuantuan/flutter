import 'dart:ui' as ui;

import 'package:bots/features/chat/chat_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explore banner notch exposes the page background', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(200, 60);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const boundaryKey = ValueKey('banner-canvas');
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            backgroundColor: const Color(0xFF32A8A2),
            body: Align(
              alignment: Alignment.topLeft,
              child: ChatExploreBanner(onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    // The right-hand V-shaped cutout must remain transparent, not black.
    final offset = (24 * 200 + 185) * 4;
    expect(
      [for (var i = 0; i < 4; i++) pixels!.getUint8(offset + i)],
      [0x32, 0xA8, 0xA2, 0xFF],
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'explore collapses after inactivity and remains clickable and draggable',
    (tester) async {
      var taps = 0;
      var movement = Offset.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ChatExploreBanner(
                onPressed: () => taps++,
                onDragUpdate: (delta) => movement += delta,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('先去探索世界'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('先去探索世界'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('先去探索世界'), findsNothing);
      expect(tester.getSize(find.byType(ChatExploreBanner)).width, 68);
      await tester.tap(find.byType(ChatExploreBanner));
      expect(taps, 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ChatExploreBanner)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(40, -20));
      await gesture.up();
      expect(movement.dx, greaterThan(0));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
