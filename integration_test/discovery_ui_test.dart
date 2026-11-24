import 'package:bots/preview_discoveries.dart' as preview;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('discovery navigation and search on iOS', (tester) async {
    preview.main();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('all-discoveries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('all-discoveries-list')), findsOneWidget);
    Future<void> capture(String name) async {
      await tester.pump(const Duration(seconds: 1));
      await binding.takeScreenshot(name);
    }

    await capture('all-discoveries');
    await tester.tap(find.byTooltip('搜索发现'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search')),
      '音乐',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(preview.previewDiscoveries.first['title'] as String),
      findsNothing,
    );
    expect(
      find.text(preview.previewDiscoveries[1]['title'] as String),
      findsOneWidget,
    );
    await capture('discovery-search');
    await tester.tap(
      find.text(preview.previewDiscoveries[1]['title'] as String),
    );
    await tester.pumpAndSettle();
    await capture('chat-collapsed');
    await tester.tap(find.byTooltip('展开发现'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-discoveries')), findsOneWidget);
    await capture('chat-expanded');
    await tester.tap(find.byTooltip('收起发现'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('header-discoveries')), findsNothing);
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('all-discoveries-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
