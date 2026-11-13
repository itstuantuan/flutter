import 'package:flutter/widgets.dart';

/// Stable IDs survive reordering; builders keep each screen's own artwork.
class OnboardingPageDefinition {
  const OnboardingPageDefinition({
    required this.id,
    required this.nextLabel,
    required this.builder,
  });
  final String id;
  final String nextLabel;
  final Widget Function(VoidCallback onNext, bool busy, String? error) builder;
}

class OnboardingPageScope extends InheritedWidget {
  const OnboardingPageScope({
    super.key,
    required this.index,
    required this.count,
    required this.nextLabel,
    required super.child,
  });
  final int index, count;
  final String nextLabel;

  static OnboardingPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingPageScope>();

  @override
  bool updateShouldNotify(OnboardingPageScope oldWidget) =>
      index != oldWidget.index ||
      count != oldWidget.count ||
      nextLabel != oldWidget.nextLabel;
}
