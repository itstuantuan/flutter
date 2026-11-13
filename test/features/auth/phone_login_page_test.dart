import 'dart:async';

import 'package:bots/features/auth/startup_profile_store.dart';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/auth/auth_gate.dart';
import 'package:bots/features/auth/phone_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testSession = AccountSession(
  registered: 0,
  uid: 'test-user',
  nick: 'Test',
  avatar: '',
  phone: '86-13800138000',
  product: 'bots',
  platform: 'ios',
  token: 'test-token',
);

class FakePhoneAccount implements AccountService {
  int sends = 0, verifies = 0, cooldown = 0;
  AccountSession? restored;
  AccountSession result = testSession;
  Object? sendError, verifyError, restoreError;
  Completer<void>? sending;
  String? sentPhone, verifiedCode;
  @override
  Future<AccountSession?> restoreSession() async {
    if (restoreError != null) throw restoreError!;
    return restored;
  }

  @override
  Future<void> sendPhoneVerify({
    required String phone,
    String ip = '',
    String utmSource = '',
    String? lang,
    CancelToken? cancelToken,
  }) async {
    sends++;
    sentPhone = phone;
    await sending?.future;
    if (sendError != null) throw sendError!;
    cooldown = 60;
  }

  @override
  Future<AccountSession> phoneVerifyLogin({
    required String phone,
    required String code,
    String ip = '',
    String? uuid,
    CancelToken? cancelToken,
  }) async {
    verifies++;
    verifiedCode = code;
    if (verifyError != null) throw verifyError!;
    return result;
  }

  @override
  Future<bool> hasCompletedRegistration() async => true;
  @override
  bool get testNewUser => false;
  @override
  int resendSeconds(String phone) => cooldown;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> fillPhone(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('login-phone')),
    '13800138000',
  );
  await tester.tap(find.byKey(const ValueKey('login-agree')));
  await tester.pump();
}

void main() {
  testWidgets(
    'phone requires number and agreement; code supports errors, retry and cooldown',
    (tester) async {
      final service = FakePhoneAccount()..sending = Completer<void>();
      AccountSession? signedIn;
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneLoginPage(
            service: service,
            onAuthenticated: (s) => signedIn = s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('login-next'));
      expect(tester.widget<TextButton>(next).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('login-phone')),
        '13800138000',
      );
      await tester.pump();
      expect(tester.widget<TextButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('login-agree')));
      await tester.pump();
      await tester.tap(next);
      await tester.pump();
      expect(service.sends, 1);
      expect(tester.widget<TextButton>(next).onPressed, isNull);
      service.sending!.complete();
      await tester.pumpAndSettle();
      expect(service.sentPhone, '86-13800138000');
      expect(find.byKey(const ValueKey('login-code')), findsOneWidget);
      expect(find.text('60s 后重发'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('login-code')), '123');
      await tester.pump();
      expect(tester.widget<TextButton>(next).onPressed, isNull);
      service.verifyError = const AccountException(3, AccountOperation.login);
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        '123456',
      );
      await tester.pump();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('验证码错误，请重新输入'), findsOneWidget);
      expect(signedIn, isNull);
      service.verifyError = null;
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(signedIn, same(testSession));
      expect(service.verifiedCode, '123456');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed SMS stays on phone page and retry sends once', (
    tester,
  ) async {
    final service = FakePhoneAccount()
      ..sendError = const AccountException(-1, AccountOperation.sendCode);
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginPage(service: service, onAuthenticated: (_) {}),
      ),
    );
    await fillPhone(tester);
    await tester.tap(find.byKey(const ValueKey('login-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-phone')), findsOneWidget);
    expect(find.text('服务暂时不可用，请稍后重试'), findsOneWidget);
    service.sendError = null;
    await tester.tap(find.byKey(const ValueKey('login-next')));
    await tester.pumpAndSettle();
    expect(service.sends, 2);
    await tester.enterText(find.byKey(const ValueKey('login-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('login-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-back')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('login-phone')))
          .controller!
          .text,
      '13800138000',
    );
    await tester.tap(find.byKey(const ValueKey('login-next')));
    await tester.pumpAndSettle();
    expect(service.sends, 2); // Returning preserves the SMS cooldown.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('login-code')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'auth gate restores users, handles failure, and routes newly registered users',
    (tester) async {
      final service = FakePhoneAccount()..restored = testSession;
      Widget gate(int id) => MaterialApp(
        home: AuthGate(
          key: ValueKey(id),
          service: service,
          profileStore: MemoryProfile(),
          experienceBuilder: (newUser) =>
              Text(newUser ? 'new-user-intro' : 'returning-home'),
        ),
      );
      await tester.pumpWidget(gate(1));
      await tester.pumpAndSettle();
      expect(find.text('returning-home'), findsOneWidget);
      service.restored = null;
      service.restoreError = StateError('storage');
      await tester.pumpWidget(gate(2));
      await tester.pumpAndSettle();
      expect(find.text('无法读取登录状态，请重试'), findsOneWidget);
      service.restoreError = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneLoginPage), findsOneWidget);
      service.result = const AccountSession(
        registered: 1,
        uid: 'new',
        nick: 'New',
        avatar: '',
        phone: '86-13800138000',
        product: 'bots',
        platform: 'ios',
        token: 'test',
      );
      await fillPhone(tester);
      await tester.tap(find.byKey(const ValueKey('login-next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-code')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('login-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-name')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('login-name')), 'Test');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('name-next')));
      await tester.pumpAndSettle();
      expect(find.text('new-user-intro'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'login controls fit short phones with keyboard and remain reachable at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(375, 812),
        const Size(414, 736),
        const Size(320, 568),
        const Size(430, 932),
      ]) {
        tester.view.physicalSize = size;
        for (final codeStep in [false, true]) {
          for (final textScale in [1.0, 2.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    padding: const EdgeInsets.only(top: 20),
                    viewInsets: const EdgeInsets.only(bottom: 280),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: PhoneLoginPage(
                    key: ValueKey('$size-$codeStep-$textScale'),
                    service: FakePhoneAccount(),
                    preview: true,
                    initialCodeStep: codeStep,
                    initialPhone: '13800138000',
                    onAuthenticated: (_) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await Scrollable.ensureVisible(
              tester.element(find.byKey(const ValueKey('login-next'))),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(const ValueKey('login-next'))).bottom,
              lessThanOrEqualTo(size.height - 280 + .1),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$size code=$codeStep text=$textScale',
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
}

class MemoryProfile extends StartupProfileStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    value = data;
  }
}
