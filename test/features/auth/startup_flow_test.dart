import 'package:bots/features/auth/auth_gate.dart';
import 'package:bots/features/auth/name_page.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:bots/features/auth/startup_profile_store.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/auth/account_service.dart';

import 'phone_login_page_test.dart' show FakePhoneAccount;

class NewAccount extends FakePhoneAccount {
  @override
  Future<bool> hasCompletedRegistration() async => false;
}

class TestProfile extends StartupProfileStore {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) throw StateError('disk');
    value = data;
  }
}

void main() {
  testWidgets('registration chat resumes until skipped, then stays completed', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final profile = TestProfile()..value = {'introDone': true, 'name': '小宝'};
    final account = NewAccount();
    const session = AccountSession(
      registered: 1,
      uid: 'new-user',
      nick: '小宝',
      avatar: '',
      phone: '86-13800138000',
      product: 'bots',
      platform: 'ios',
      token: 'test',
    );
    Widget app(int key) => MaterialApp(
      key: ValueKey(key),
      home: AuthGate(
        key: ValueKey(key),
        service: account,
        profileStore: profile,
      ),
    );
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    await tester
        .widget<PhoneLoginPage>(find.byType(PhoneLoginPage))
        .onAuthenticated(session);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsNothing);
    expect(
      tester.widget<ChatPage>(find.byType(ChatPage)).returningUser,
      isFalse,
    );
    expect(profile.value['registrationChats'], {'new-user': 'pending'});

    account.restored = session;
    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();
    expect(find.text('跳过'), findsOneWidget);
    profile.fail = true;
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    profile.fail = false;
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(profile.value['registrationChats'], {'new-user': 'done'});

    tester.widget<HomePage>(find.byType(HomePage)).onChat();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChatPage>(find.byType(ChatPage)).returningUser,
      isTrue,
    );
    expect(find.text('跳过'), findsNothing);
    await tester.pumpWidget(app(3));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    // Even a repeated registered=1 response must not replay completed onboarding.
    account.restored = null;
    await tester.pumpWidget(app(4));
    await tester.pumpAndSettle();
    await tester
        .widget<PhoneLoginPage>(find.byType(PhoneLoginPage))
        .onAuthenticated(session);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'new launch resumes intro then name before phone; save failures do not advance',
    (tester) async {
      final profile = TestProfile();
      final account = NewAccount();
      Widget app(int key) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AuthGate(
            key: ValueKey(key),
            service: account,
            profileStore: profile,
            experienceBuilder: (_) => const Text('home'),
          ),
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      profile.fail = true;
      await tester.tap(find.text('继续了解'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.text('保存失败，请重试'), findsOneWidget);
      profile.fail = false;
      await tester.tap(find.text('继续了解'));
      await tester.pumpAndSettle();
      expect(profile.value['page'], 'world');
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      expect(find.byType(WorldPage), findsOneWidget);
      await tester.tap(find.text('进入这个世界'));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsOneWidget);
      expect(profile.value['introDone'], true);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('name-next')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-name')),
        '  小宝  ',
      );
      profile.fail = true;
      await tester.tap(find.byKey(const ValueKey('name-next')));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsOneWidget);
      profile.fail = false;
      await tester.tap(find.byKey(const ValueKey('name-next')));
      await tester.pumpAndSettle();
      expect(profile.value['name'], '小宝');
      expect(find.byType(PhoneLoginPage), findsOneWidget);
      expect(account.verifies, 0);
      await tester.pumpWidget(app(3));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneLoginPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
