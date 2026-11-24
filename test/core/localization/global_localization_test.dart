import 'package:bots/features/character/splash_page.dart';

import 'dart:io';

import 'package:bots/core/localization/app_localizations.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/auth/name_page.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/discoveries/all_discoveries_page.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/home/home_sidebar.dart';
import 'package:bots/features/onboarding/interests_page.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:bots/features/settings/feedback_page.dart';
import 'package:bots/features/settings/notification_pages.dart';
import 'package:bots/features/settings/profile_page.dart';
import 'package:bots/features/settings/privacy_policy_page.dart';
import 'package:bots/features/settings/service_agreement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget page, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppTranslations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: page,
    );

void expectEnglish(WidgetTester tester, String page) {
  final han = RegExp(r'[\u4e00-\u9fff]');
  for (final widget in tester.allWidgets) {
    final text = switch (widget) {
      Text() => widget.data ?? widget.textSpan?.toPlainText(),
      SelectableText() => widget.data ?? widget.textSpan?.toPlainText(),
      Semantics() => widget.properties.label,
      _ => null,
    };
    if (text != null) {
      expect(han.hasMatch(text), isFalse, reason: '$page: $text');
    }
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'all main interface screens have English text on small and enlarged layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final layoutIssues = <String>[];
      for (final (width, scale) in [
        (320.0, 1.0),
        (375.0, 1.0),
        (320.0, 1.5),
        (375.0, 2.0),
      ]) {
        tester.view.physicalSize = Size(width, 812);
        final pages = <Widget>[
          const SplashArtwork(animate: false),
          WelcomePage(onNext: () {}),
          WorldPage(onNext: () {}),
          NamePage(onContinue: (_) async {}),
          InterestsPage(
            initialSelection: designInterests,
            onStart: (_) async => true,
          ),
          PhoneLoginPage(
            service: account,
            onAuthenticated: (_) {},
            preview: true,
          ),
          PhoneLoginPage(
            service: account,
            onAuthenticated: (_) {},
            preview: true,
            initialCodeStep: true,
            initialPhone: '12345678901',
          ),
          ChatPage(onExit: () {}, onExplore: () {}, animate: false),
          HomePage(
            onMenu: () {},
            onExplore: () {},
            onChat: () {},
            onVoice: () {},
            onDiscovery: (_) {},
            discoveries: const [
              HomeDiscovery(
                title: 'A real discovery',
                description: 'From the server',
                style: DiscoveryStyle.glass,
              ),
            ],
          ),
          HomeSidebar(name: 'Alex', onSelect: (_) {}),
          AllDiscoveriesPage(cards: const [], onOpen: (_) {}),
          const NotificationsPage(),
          ProfilePage(
            name: 'Alex',
            uid: '12345',
            onSave: (_) async {},
            onLogout: () async {},
          ),
          const FeedbackPage(uid: 'test'),
        ];
        for (final page in pages) {
          await tester.pumpWidget(host(page, scale: scale));
          await tester.pump(const Duration(milliseconds: 500));
          final exception = tester.takeException();
          if (exception != null) {
            layoutIssues.add('${page.runtimeType}, $width, $scale: $exception');
          }
          expectEnglish(tester, '${page.runtimeType}');
          await tester.pumpWidget(const SizedBox());
        }
      }
      expect(layoutIssues, isEmpty);
    },
  );

  testWidgets(
    'selected interest chips fit complete translated labels on one line',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final language in ['en', 'zh']) {
        for (final width in [320.0, 375.0, 430.0]) {
          tester.view.physicalSize = Size(width, 812);
          for (final scale in [1.0, 1.5, 2.0]) {
            await tester.pumpWidget(
              host(
                InterestsPage(
                  initialSelection: designInterests,
                  onStart: (_) async => true,
                ),
                language: language,
                scale: scale,
              ),
            );
            await tester.pump();
            for (final label in designInterests) {
              final chip = find.byKey(ValueKey('remove-$label'));
              final rich = find.descendant(
                of: chip,
                matching: find.byType(RichText),
              );
              final paragraph = tester.renderObject<RenderParagraph>(rich);
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$language $width $scale $label',
              );
              expect(paragraph.maxLines, 1);
              expect(tester.getSize(chip).width, lessThanOrEqualTo(width - 48));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets(
    'legal documents use the selected language and retain source paragraphs',
    (tester) async {
      for (final language in ['en', 'zh']) {
        for (final page in [
          const ServiceAgreementPage(),
          const PrivacyPolicyPage(),
        ]) {
          await tester.pumpWidget(host(page, language: language));
          await tester.pumpAndSettle();
          if (language == 'en') expectEnglish(tester, '${page.runtimeType}');
          expect(find.byType(SelectableText), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      for (final stem in ['service_agreement', 'privacy_policy']) {
        final zh = File('assets/legal/${stem}_zh.txt').readAsLinesSync();
        final en = File('assets/legal/${stem}_en.txt').readAsLinesSync();
        expect(en.length, zh.length, reason: stem);
        expect(
          en.where((line) => line.contains('contact@viitor.top')).length,
          zh.where((line) => line.contains('contact@viitor.top')).length,
        );
      }
    },
  );

  testWidgets(
    'only synthesized chat statuses translate, never identical user text',
    (tester) async {
      await tester.pumpWidget(
        host(
          ChatPage(
            onExit: () {},
            onExplore: () {},
            animate: false,
            messages: const [
              ChatMessage('语音消息', isUser: true),
              ChatMessage('语音消息', isUser: true, isInterfaceText: true),
              ChatMessage('这次回复未完成，请重新发送消息再试。', isInterfaceText: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('语音消息'), findsOneWidget);
      expect(find.text('Voice message'), findsOneWidget);
      expect(
        find.text(
          'This reply could not be completed. Please send your message again.',
        ),
        findsOneWidget,
      );
    },
  );
}
