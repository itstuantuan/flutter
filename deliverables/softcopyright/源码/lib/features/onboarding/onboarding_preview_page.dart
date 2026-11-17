import 'package:flutter/material.dart';

import 'onboarding_flow.dart';

/// Preview the shared catalog without changing registration or saved progress.
class OnboardingPreviewPage extends StatelessWidget {
  const OnboardingPreviewPage({super.key});

  @override
  Widget build(BuildContext context) =>
      OnboardingFlow(onComplete: () => Navigator.pop(context));
}
