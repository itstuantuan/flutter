import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/auth/login_demo_page.dart';

void main() {
  testWidgets('测试页完成发送、登录展示和退出，不展示token', (tester) async {
    final service = DemoService();
    await tester.pumpWidget(MaterialApp(home: LoginDemoPage(service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '15010887212');
    await tester.tap(find.text('发送验证码'));
    await tester.pumpAndSettle();
    expect(service.sentPhone, '86-15010887212');
    expect(find.text('60s 后重新发送'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), '001234');
    await tester.ensureVisible(find.text('登录并保存会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录并保存会话'));
    await tester.pumpAndSettle();
    expect(service.receivedCode, '001234');
    expect(find.textContaining('UID：123'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    final logout = find.text('退出并清除本地会话');
    await tester.scrollUntilVisible(
      logout,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(service.session, isNull);
    expect(find.textContaining('UID：123'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Google按钮不要求输入手机号，显示邮箱和业务会话', (tester) async {
    final service = DemoService();
    await tester.pumpWidget(MaterialApp(home: LoginDemoPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用 Google 账号登录'));
    await tester.pumpAndSettle();
    expect(service.session?.email, 'user@example.com');
    await tester.scrollUntilVisible(
      find.textContaining('邮箱：user@example.com'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('邮箱：user@example.com'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class DemoService extends AccountService {
  DemoService()
    : super(
        client: ApiClient(
          baseUrl: 'https://example.com',
          signer: const RequestSigner(
            product: 'bots',
            platform: 'ios',
            secretKey: 'test',
          ),
        ),
        store: SecureSessionStore(namespace: 'unused'),
      );
  String? sentPhone;
  String? receivedCode;
  AccountSession? current;
  @override
  AccountSession? get session => current;
  @override
  Future<AccountSession?> restoreSession() async => current;
  @override
  int resendSeconds(String phone) => sentPhone == phone ? 60 : 0;
  @override
  Future<void> sendPhoneVerify({
    required String phone,
    String ip = '',
    String utmSource = '',
    String? lang,
    CancelToken? cancelToken,
  }) async {
    sentPhone = phone;
  }

  @override
  Future<AccountSession> phoneVerifyLogin({
    required String phone,
    required String code,
    String ip = '',
    String? uuid,
    CancelToken? cancelToken,
  }) async {
    receivedCode = code;
    return current = AccountSession(
      registered: 0,
      uid: '123',
      nick: 'Test',
      avatar: '',
      phone: phone,
      product: 'bots',
      platform: 'ios',
      token: 'private-token',
    );
  }

  @override
  Future<AccountSession> googleLogin({
    String ip = '',
    String utmSource = '',
    CancelToken? cancelToken,
  }) async {
    return current = const AccountSession(
      registered: 0,
      uid: 'google-123',
      nick: 'Google',
      avatar: '',
      phone: '',
      email: 'user@example.com',
      product: 'bots',
      platform: 'ios',
      token: 'private-token',
    );
  }

  @override
  Future<void> logout() async {
    current = null;
  }
}
