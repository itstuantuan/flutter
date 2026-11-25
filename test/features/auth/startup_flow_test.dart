import 'package:bots/features/discoveries/discovery_detail_page.dart';
import 'package:bots/features/auth/auth_gate.dart';
import 'package:bots/features/auth/name_page.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:bots/features/auth/startup_profile_store.dart';
import 'package:bots/features/onboarding/welcome_page.dart';
import 'package:bots/features/onboarding/onboarding_flow.dart';
import 'package:bots/features/onboarding/world_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/home/home_page.dart';
import 'package:bots/features/onboarding/interests_page.dart';
import 'package:bots/features/plaza/plaza_page.dart';
import 'package:bots/features/auth/account_service.dart';

import '../exploration/fakes.dart';

import 'phone_login_page_test.dart'
    show FakePhoneAccount, fillPhone, testSession;

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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => binding.platformDispatcher.localeTestValue = const Locale('zh', 'CN'),
  );
  tearDown(binding.platformDispatcher.clearLocaleTestValue);
  testWidgets(
    'switching accounts never inherits names or completed onboarding',
    (tester) async {
      final profile = TestProfile()
        ..value = {
          'introDone': true,
          'name': 'unowned legacy name',
          'users': {
            'account-a': {
              'name': 'Alice',
              'introDone': true,
              'registrationChat': 'done',
            },
          },
        };
      AccountSession session(String uid) => AccountSession(
        registered: 1,
        uid: uid,
        nick: '',
        avatar: '',
        phone: '',
        product: 'bots',
        platform: 'ios',
        token: 'token-$uid',
      );
      final account = NewAccount();
      Widget app(int generation) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AuthGate(
            key: ValueKey(generation),
            service: account,
            profileStore: profile,
            experienceBuilder: (newUser) =>
                Text(newUser ? 'first-chat' : 'home'),
          ),
        ),
      );
      account.restored = session('account-a');
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      account.restored = null;
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      await tester
          .widget<PhoneLoginPage>(find.byType(PhoneLoginPage))
          .onAuthenticated(session('account-b'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      expect((await profile.readUser('account-b'))['name'], isNull);
      final intro = tester.widget<OnboardingFlow>(find.byType(OnboardingFlow));
      await intro.onAdvance!('world');
      account.restored = session('account-b');
      await tester.pumpWidget(app(3));
      await tester.pumpAndSettle();
      expect(find.byType(WorldPage), findsOneWidget);
      await tester.tap(find.text('进入这个世界'));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      await tester.widget<NamePage>(find.byType(NamePage)).onContinue('Bob');
      await tester.pumpAndSettle();
      expect(find.text('first-chat'), findsOneWidget);
      expect((await profile.readUser('account-b'))['name'], 'Bob');
      expect(
        (await profile.readUser('account-b'))['registrationChat'],
        'pending',
      );
      expect((await profile.readUser('account-a'))['name'], 'Alice');
      expect((await profile.readUser('account-a'))['registrationChat'], 'done');
      account.restored = session('account-a');
      await tester.pumpWidget(app(4));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('ordinary notification returns to home from chat and plaza', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('viitor/apns');
    final messenger = tester.binding.defaultBinaryMessenger;
    final notifications = <Map<String, String>>[];
    var authorization = 'notDetermined';
    var permissionRequests = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') return {'authorization': authorization};
      if (call.method == 'requestPermission') permissionRequests++;
      if (call.method == 'takeNotification' && notifications.isNotEmpty) {
        return notifications.removeAt(0);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final account = FakePhoneAccount()
      ..restored = testSession
      ..logoutWarning = '设备通知解绑尚未确认';
    final bots = FakeBotService()..confirmed = true;
    addTearDown(bots.events.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: AuthGate(
          service: account,
          profileStore: TestProfile(),
          chatService: bots,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('开启 Pals 消息通知'), findsNothing);
    expect(find.text('设备通知解绑尚未确认'), findsNothing);
    expect(permissionRequests, 0);
    authorization = 'authorized';

    Future<void> tapNotification(Map<String, String> payload) async {
      notifications.add(payload);
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('notificationOpened')),
        null,
      );
      await tester.pumpAndSettle();
    }

    Future<void> verifyReturnHome(String id) async {
      await tapNotification({'event': 'home', 'notificationId': id});
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(ChatPage), findsNothing);
      expect(find.byType(PlazaPage), findsNothing);
    }

    tester.widget<HomePage>(find.byType(HomePage)).onChat();
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    await verifyReturnHome('from-chat');

    tester.widget<HomePage>(find.byType(HomePage)).onExplore();
    await tester.pumpAndSettle();
    expect(find.byType(PlazaPage), findsOneWidget);
    await verifyReturnHome('from-plaza');

    bots.located = {
      'sessionId': 'session-1',
      'anchorTurnId': 42,
      'turns': [discoveryTurn()],
    };
    await tapNotification({
      'event': 'exploration_completed',
      'taskId': 'task-1',
      'sessionId': 'session-1',
      'notificationId': 'card',
    });
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).anchorTurnId, 42);
    expect(find.byType(PlazaPage), findsNothing);
    expect(bots.starts, 1);
    await verifyReturnHome('from-notification-chat');
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
      final profile = TestProfile()
        ..value = {
          'introDone': true,
          'users': {
            session.uid: {'introDone': true},
          },
        };
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
      expect(
        (await profile.readUser(session.uid))['registrationChat'],
        'pending',
      );
    },
  );

  testWidgets('registration chat resumes until skipped, then stays completed', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final profile = TestProfile()
      ..value = {
        'introDone': true,
        'users': {
          'new-user': {'introDone': true, 'name': '小宝'},
        },
      };
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
    expect((await profile.readUser('new-user'))['registrationChat'], 'pending');

    account.restored = session;
    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();
    expect(find.text('跳过'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsOneWidget);
    expect((await profile.readUser('new-user'))['registrationChat'], 'pending');
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
    expect((await profile.readUser('new-user'))['registrationChat'], 'pending');
    profile.fail = false;
    await tester.widget<InterestsPage>(find.byType(InterestsPage)).onStart([
      '音乐',
    ]);
    await tester.pumpAndSettle();
    expect((await profile.readUser('new-user'))['registrationChat'], 'done');
    expect(find.byType(PlazaPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();
    tester.widget<HomePage>(find.byType(HomePage)).onExplore();
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsNothing);
    expect(find.byType(PlazaPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();

    // Reading a home card then chatting must locate the original server turn without
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
    bots.progress = {
      'phase': 'complete',
      'cards': [
        {'materialId': 'material-2', 'title': '发现2', 'content': '真实发现正文'},
      ],
    };
    tester.widget<HomePage>(find.byType(HomePage)).onDiscovery(0);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryDetailPage), findsOneWidget);
    await tester.tap(find.text('和Pal聊聊'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChatPage>(find.byType(ChatPage)).anchorTurnId, isNull);
    expect(
      tester
          .widget<ChatPage>(find.byType(ChatPage))
          .referenceCard?['materialId'],
      'material-2',
    );
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
      expect((await profile.readUser('new'))['name'], '小宝');
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(app(4));
      await tester.pumpAndSettle();
      expect(find.byType(NamePage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
