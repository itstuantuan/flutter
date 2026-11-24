import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:bots/features/onboarding/interests_page.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/core/localization/app_language.dart';
import 'package:bots/core/localization/app_localizations.dart';
import 'package:bots/features/home/home_sidebar.dart';
import 'package:bots/features/discoveries/discovery_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('English onboarding, login and home fit small screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 700), const Size(375, 812)]) {
      tester.view.physicalSize = size;
      final pages = <Widget>[
        WelcomePage(onNext: () {}),
        WorldPage(onNext: () {}),
        InterestsPage(onStart: (_) async => true),
        PhoneLoginPage(
          service: account,
          onAuthenticated: (_) {},
          preview: true,
        ),
        HomePage(
          onMenu: () {},
          onExplore: () {},
          onChat: () {},
          onVoice: () {},
          onDiscovery: (_) {},
        ),
      ];
      for (final page in pages) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppTranslations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: page,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.takeException(),
          isNull,
          reason: '$size ${page.runtimeType}',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'fresh install defaults to English and saved choice survives restart',
    () async {
      final language = AppLanguage();
      await language.restore();
      expect(language.locale.languageCode, 'en');
      await language.select('zh');
      final restored = AppLanguage();
      await restored.restore();
      expect(restored.locale.languageCode, 'zh');
      await restored.select('en');
      final english = AppLanguage();
      await english.restore();
      expect(english.locale.languageCode, 'en');
    },
  );

  test('unknown stored locale falls back to English', () async {
    FlutterSecureStorage.setMockInitialValues({AppLanguage.storageKey: 'fr'});
    final language = AppLanguage();
    await language.restore();
    expect(language.locale.languageCode, 'en');
  });

  testWidgets(
    'sidebar actions and live locale change preserve open route and input',
    (tester) async {
      final language = AppLanguage();
      final text = TextEditingController();
      String? selection;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: language,
          builder: (context, _) => MaterialApp(
            locale: language.locale,
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppTranslations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: HomeSidebar(
              name: '音乐',
              onSelect: (value) => selection = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discovery history'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('音乐'), findsOneWidget); // User name remains verbatim.
      await tester.tap(find.text('Discovery history'));
      expect(selection, 'history');
      await tester.tap(find.text('Language'));
      expect(selection, 'language');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Column(
              children: [
                const AppText('新发现'),
                TextField(controller: text),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'keep my draft');
      await language.select('zh');
      await tester.pumpAndSettle();
      expect(find.text('新发现'), findsOneWidget);
      expect(text.text, 'keep my draft');
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('历史发现'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      text.dispose();
      language.dispose();
    },
  );

  testWidgets(
    'English detail keeps server content unchanged and hides history',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [AppTranslations.delegate],
          home: DiscoveryDetailPage(card: {'title': '音乐', 'content': '真实发现正文'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New discovery'), findsOneWidget);
      expect(find.text('Chat with Pal'), findsOneWidget);
      expect(find.text('音乐'), findsOneWidget);
      expect(find.text('真实发现正文'), findsOneWidget);
      expect(find.text('History'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
