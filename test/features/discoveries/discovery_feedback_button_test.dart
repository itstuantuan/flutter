import 'package:bots/features/discoveries/discovery_feedback_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget demo({bool reduced = false, bool positive = true}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) {
          return _FeedbackDemo(positive: positive);
        },
      ),
    ),
  ),
);

class _FeedbackDemo extends StatefulWidget {
  const _FeedbackDemo({this.positive = true});
  final bool positive;
  @override
  State<_FeedbackDemo> createState() => _FeedbackDemoState();
}

class _FeedbackDemoState extends State<_FeedbackDemo> {
  bool selected = false;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 190,
      child: DiscoveryFeedbackButton(
        selected: selected,
        positive: widget.positive,
        onPressed: () => setState(() => selected = !selected),
        icon: const Icon(Icons.thumb_up),
        label: const Text('Like'),
      ),
    ),
  );
}

void main() {
  testWidgets('dislike moves the icon without emitting confetti and settles', (
    tester,
  ) async {
    await tester.pumpWidget(demo(positive: false));
    await tester.tap(find.text('Like'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CompositedTransformFollower), findsNothing);
    final icon = find.byKey(const ValueKey('feedback-icon-motion'));
    expect(tester.widget<Transform>(icon).transform.storage[12], isNot(0));
    expect(tester.widget<Transform>(icon).transform.storage[13], 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(icon).transform.storage[12], 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'burst cleans up, deselection stays quiet, route removal is safe',
    (tester) async {
      await tester.pumpWidget(demo());
      await tester.tap(find.text('Like'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CompositedTransformFollower), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CompositedTransformFollower), findsNothing);
      await tester.tap(find.text('Like'));
      await tester.pump();
      expect(find.byType(CompositedTransformFollower), findsNothing);
      await tester.tap(find.text('Like'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion suppresses particles', (tester) async {
    await tester.pumpWidget(demo(reduced: true));
    await tester.tap(find.text('Like'));
    await tester.pump();
    expect(find.byType(CompositedTransformFollower), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
