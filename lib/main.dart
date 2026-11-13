import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/name_page.dart';
import 'features/onboarding/interests_page.dart';
import 'features/plaza/plaza_page.dart';

import 'features/auth/auth_debug_log.dart';
import 'features/auth/phone_login_page.dart';
import 'features/auth/account_service.dart';
import 'features/onboarding/onboarding_preview_page.dart';
import 'features/character/character_preview_page.dart';
import 'features/character/splash_preview_page.dart';
import 'features/character/splash_page.dart';
import 'features/chat/chat_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AuthDebugLog.event('Demo 启动 · diagnostics-v2 · Debug 日志已启用');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pals',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashPage(),
      routes: {
        '/name-preview': (_) => NamePage(onContinue: (_) async {}),
        '/interests-preview': (_) => InterestsPage(
          onStart: (_) async => true,
        ),
        '/plaza-preview': (_) => const PlazaPage(),
        '/login-preview': (_) => PhoneLoginPage(
          service: account,
          preview: true,
          onAuthenticated: (_) {},
        ),
        '/login-code-preview': (_) => PhoneLoginPage(
          service: account,
          preview: true,
          initialCodeStep: true,
          initialPhone: '12345678911',
          onAuthenticated: (_) {},
        ),
        '/chat-returning-preview': (_) =>
            const ChatPreviewPage(state: ChatPreviewState.returning),
        '/chat-preview': (_) => const ChatPreviewPage(),
        '/chat-conversation-preview': (_) =>
            const ChatPreviewPage(state: ChatPreviewState.conversation),
        '/chat-recording-preview': (_) =>
            const ChatPreviewPage(state: ChatPreviewState.recording),
        '/splash': (_) => const SplashArtwork(),
        '/welcome-preview': (_) => const OnboardingPreviewPage(),
        '/character-preview': (_) => const CharacterPreviewPage(),
        '/splash-preview': (_) => const SplashPreviewPage(),
      },
    );
  }
}
