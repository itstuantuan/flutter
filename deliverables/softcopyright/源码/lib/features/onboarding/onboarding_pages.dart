import 'onboarding_page.dart';
import 'welcome_page.dart';
import 'world_page.dart';

/// Add or reorder screens here. Do not rename an ID once it has shipped.
final onboardingPages = List<OnboardingPageDefinition>.unmodifiable([
  OnboardingPageDefinition(
    id: 'welcome',
    nextLabel: '继续了解',
    builder: (onNext, busy, error) =>
        WelcomePage(onNext: onNext, busy: busy, error: error),
  ),
  OnboardingPageDefinition(
    id: 'world',
    nextLabel: '进入这个世界',
    builder: (onNext, busy, error) =>
        WorldPage(onNext: onNext, busy: busy, error: error),
  ),
]);
