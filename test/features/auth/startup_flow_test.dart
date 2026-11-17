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
import 'package:bots/features/onboarding/interests_page.dart';
import 'package:bots/features/plaza/plaza_page.dart';
import 'package:bots/features/auth/account_service.dart';

import '../exploration/fakes.dart';

import 'phone_login_page_test.dart' show FakePhoneAccount, fillPhone;

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
  testWidgets(
    'restored new session resumes onboarding when its first save failed',
    (tester) async {
      const session = AccountSession(
        registered: 1,
        uid: 'interrupted-registration',
        nick: '',
        avatar: '',
        phone: '86-13800138000',
        product: 'bots',
        platform: 'ios',
        token: 'test',
      );
      final account = NewAccount()..restored = session;
      final profile = TestProfile()..value = {'introDone': true};
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            service: account,
            profileStore: profile,
            experienceBuilder: (_) => const Text('home'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsOneWidget);
      expect(profile.value['registrationChats'], {session.uid: 'pending'});
    },
  );

  testWidgets('registration chat resumes until skipped, then stays completed', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final profile = TestProfile()..value = {'introDone': true, 'name': '小宝'};
    final account = NewAccount();
    final bots = FakeBotService();
    addTearDown(bots.events.close);
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: AuthGate(
        key: ValueKey(key),
        service: account,
        chatService: bots,
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
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsOneWidget);
    expect(profile.value['registrationChats'], {'new-user': 'pending'});
    // Returning without selecting interests preserves the first-chat flow.
    Navigator.of(tester.element(find.byType(InterestsPage))).pop();
    await tester.pumpAndSettle();
    tester.widget<ChatPage>(find.byType(ChatPage)).onExplore();
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsOneWidget);
    profile.fail = true;
    expect(
      await tester.widget<InterestsPage>(find.byType(InterestsPage)).onStart([
        '音乐',
      ]),
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsOneWidget);
    expect(profile.value['registrationChats'], {'new-user': 'pending'});
    profile.fail = false;
    await tester.widget<InterestsPage>(find.byType(InterestsPage)).onStart([
      '音乐',
    ]);
    await tester.pumpAndSettle();
    expect(profile.value['registrationChats'], {'new-user': 'done'});
    expect(find.byType(PlazaPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();
    tester.widget<HomePage>(find.byType(HomePage)).onExplore();
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsNothing);
    expect(find.byType(PlazaPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();

    // The real home card path must load/locate the original server turn without
    // notifying the previous route during the new route's build.
    bots.homeCards = [
      {
        'taskId': 'task-1',
        'materialId': 'material-2',
        'title': '发现2',
        'text': '推荐理由',
      },
    ];
    bots.located = {
      'anchorTurnId': 42,
      'turns': [discoveryTurn()],
    };
    tester.widget<HomePage>(find.byType(HomePage)).onExplore();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();
    tester.widget<HomePage>(find.byType(HomePage)).onDiscovery(0);
    await tester.pumpAndSettle();
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).anchorTurnId, 42);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

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
    'new launch verifies phone before name and resumes unfinished name entry',
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
      expect(find.byType(PhoneLoginPage), findsOneWidget);
      expect(find.byType(NamePage), findsNothing);
      expect(profile.value['introDone'], true);
      account.result = const AccountSession(
        registered: 1,
        uid: 'new',
        nick: '',
        avatar: '',
        phone: '86-13800138000',
        product: 'bots',
        platform: 'ios',
        token: 'test',
      );
      await fillPhone(tester);
      await tester.tap(find.byKey(const ValueKey('login-next')));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('login-next')));
      await tester.pumpAndSettle();
      expect(account.verifies, 1);
      expect(find.byType(NamePage), findsOneWidget);
      account.restored = account.result;
      await tester.pumpWidget(app(3));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsOneWidget);
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
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(app(4));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
