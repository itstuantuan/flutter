import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bots/core/localization/app_localizations.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/auth/auth_gate.dart';
import 'package:bots/features/auth/google_login_page.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:bots/features/auth/name_page.dart';
import 'package:bots/features/onboarding/onboarding_flow.dart';
import 'package:bots/features/settings/privacy_policy_page.dart';
import 'package:bots/features/settings/service_agreement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone_login_page_test.dart';
import 'startup_flow_test.dart' show TestProfile;

class GoogleAccount extends FakePhoneAccount {
  int calls = 0;
  Completer<AccountSession>? pending;
  Object? error;
  CancelToken? cancellation;
  @override
  Future<AccountSession> googleLogin({
    String ip = '',
    String utmSource = '',
    CancelToken? cancelToken,
  }) async {
    calls++;
    cancellation = cancelToken;
    if (error != null) throw error!;
    return pending == null ? result : pending!.future;
  }
}

void main() {
  testWidgets(
    'device region selects login independently of interface language',
    (tester) async {
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      for (final locale in [
        const Locale('en', 'CN'),
        const Locale('zh', 'US'),
        const Locale('zh', 'HK'),
        const Locale('en'),
      ]) {
        tester.binding.platformDispatcher.localeTestValue = locale;
        final phone = locale.countryCode == 'CN';
        for (final language in ['en', 'zh']) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$locale-$language'),
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: const [
                AppTranslations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: AuthGate(
                service: GoogleAccount(),
                profileStore: TestProfile()..value = {'introDone': true},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(PhoneLoginPage),
            phone ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(GoogleLoginPage),
            !phone ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('switch-phone-login')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('switch-google-login')),
            findsNothing,
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('overseas Google login enters new-user flow', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'zh',
      'US',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    final account = GoogleAccount()
      ..result = const AccountSession(
        registered: 1,
        uid: 'google-new',
        nick: '',
        avatar: '',
        phone: '',
        email: 'user@example.com',
        product: 'bots',
        platform: 'ios',
        token: 'test',
      );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppTranslations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: AuthGate(
          service: account,
          profileStore: TestProfile()..value = {'introDone': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoogleLoginPage), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('google-login')));
    await tester.tap(find.byKey(const ValueKey('google-login')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    await tester.widget<OnboardingFlow>(find.byType(OnboardingFlow)).onAdvance!(
      null,
    );
    await tester.pumpAndSettle();
    expect(find.byType(NamePage), findsOneWidget);
    expect(account.calls, 1);
  });

  testWidgets(
    'authorization is single flight and disposed pages cancel their request',
    (tester) async {
      final account = GoogleAccount()..pending = Completer<AccountSession>();
      var authenticated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleLoginPage(
            service: account,
            onAuthenticated: (_) => authenticated++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('google-login')));
      await tester.tap(find.byKey(const ValueKey('google-login')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('google-login')));
      expect(account.calls, 1);
      await tester.pumpWidget(const SizedBox());
      expect(account.cancellation!.isCancelled, isTrue);
      account.pending!.complete(testSession);
      await tester.pumpAndSettle();
      expect(authenticated, 0);
    },
  );

  testWidgets(
    'cancel is silent, errors can be retried, success calls the auth gate',
    (tester) async {
      final account = GoogleAccount()
        ..error = const GoogleLoginException(
          'canceled',
          'cancelled',
          cancelled: true,
        );
      var authenticated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleLoginPage(
            service: account,
            onAuthenticated: (_) => authenticated++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> login() async {
        await tester.ensureVisible(find.byKey(const ValueKey('google-login')));
        await tester.tap(find.byKey(const ValueKey('google-login')));
        await tester.pumpAndSettle();
      }

      await login();
      expect(find.text('cancelled'), findsNothing);
      account.error = const GoogleLoginException('unavailable', '登录服务暂不可用');
      await login();
      expect(find.text('登录服务暂不可用'), findsOneWidget);
      account.error = null;
      await login();
      expect(authenticated, 1);
      expect(find.text('登录服务暂不可用'), findsNothing);
    },
  );

  testWidgets(
    'policy links navigate and Google design renders at phone sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final font = FontLoader('Newsreader')
        ..addFont(rootBundle.load('assets/fonts/Newsreader.ttf'));
      await font.load();
      if (Platform.environment['CAPTURE_LOGIN'] == '1') {
        await tester.runAsync(() async {
          final data = ByteData.sublistView(
            await File('/System/Library/Fonts/Supplemental/Arial.ttf')
                .readAsBytes(),
          );
          for (final family in ['Roboto', 'PingFang SC']) {
            await (FontLoader(family)..addFont(Future.value(data))).load();
          }
        });
      }
      final key = GlobalKey();
      for (final size in [const Size(375, 812), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppTranslations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: RepaintBoundary(
              key: key,
              child: GoogleLoginPage(
                service: GoogleAccount(),
                onAuthenticated: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (size.width == 375) {
          if (Platform.environment['CAPTURE_LOGIN'] == '1') {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('/tmp/sweet-google-login.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          final rich = tester.widget<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.textSpan?.toPlainText().startsWith('·By continuing') ==
                      true,
            ),
          );
          final spans = rich.textSpan! as TextSpan;
          ((spans.children![1] as TextSpan).recognizer as TapGestureRecognizer)
              .onTap!();
          await tester.pumpAndSettle();
          expect(find.byType(ServiceAgreementPage), findsOneWidget);
          Navigator.of(tester.element(find.byType(ServiceAgreementPage))).pop();
          await tester.pumpAndSettle();
          ((spans.children![3] as TextSpan).recognizer as TapGestureRecognizer)
              .onTap!();
          await tester.pumpAndSettle();
          expect(find.byType(PrivacyPolicyPage), findsOneWidget);
          Navigator.of(tester.element(find.byType(PrivacyPolicyPage))).pop();
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(const ValueKey('google-login')));
        expect(
          find.byKey(const ValueKey('google-login')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
