import 'dart:async';

import 'package:bots/features/exploration/plaza_entry_page.dart';
import 'package:bots/features/plaza/plaza_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'plaza appears before slow preparation and supports failure retry',
    (tester) async {
      final pending = Completer<Widget?>();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PlazaEntryPage(
            prepare: (_) {
              attempts++;
              return attempts == 1
                  ? pending.future
                  : Future.value(const Scaffold(body: Text('任务就绪')));
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(PlazaPage), findsOneWidget);
      expect(find.text('正在准备探索…'), findsOneWidget);
      expect(attempts, 1);
      pending.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(find.text('探索加载失败，请重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();
      expect(find.text('任务就绪'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('leaving while loading ignores late completion', (tester) async {
    final pending = Completer<Widget?>();
    await tester.pumpWidget(
      MaterialApp(home: PlazaEntryPage(prepare: (_) => pending.future)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(const Text('late'));
    await tester.pump();
    expect(find.text('late'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
