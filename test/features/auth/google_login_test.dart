import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';

import 'account_service_test.dart' show StubAdapter, FailingStore;

Map<String, dynamic> googleSessionData() => {
  'registered': 0,
  'uid': '42',
  'nick': 'Google User',
  'email': 'user@example.com',
  'product': 'bots',
  'platform': 'ios',
  'token': 'business-token',
};

class FakeGoogleIdentity implements GoogleIdentityProvider {
  int calls = 0;
  Object? error;
  Completer<GoogleIdentityProof>? pending;
  GoogleIdentityProof proof = const GoogleIdentityProof(
    email: 'user@example.com',
    idToken: 'google-id-token',
  );
  @override
  Future<GoogleIdentityProof> authenticate(String platform) async {
    expect(platform, 'ios');
    calls++;
    if (error != null) throw error!;
    return pending == null ? proof : await pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StubAdapter adapter;
  late FakeGoogleIdentity provider;
  late SecureSessionStore store;
  late AccountService service;
  AccountService create({
    SessionStore? storage,
    Future<String?> Function(String)? deviceUuidProvider,
  }) => AccountService(
    client: ApiClient(
      baseUrl: 'https://account-api.ilivedata.com',
      dio: Dio()..httpClientAdapter = adapter,
      signer: const RequestSigner(
        product: 'bots',
        platform: 'ios',
        secretKey: 'test-key',
      ),
    ),
    store: storage ?? store,
    googleIdentity: provider,
    deviceUuidProvider:
        deviceUuidProvider ?? (platform) async => 'device-$platform',
  );
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureSessionStore(namespace: 'google-test');
    adapter = StubAdapter()
      ..response = {'status': 0, 'data': googleSessionData()};
    provider = FakeGoogleIdentity();
    service = create();
  });

  test('Google原生凭证通过签名接口换取业务token，没有手机号也能恢复会话', () async {
    final session = await service.googleLogin();
    expect(adapter.options.uri.path, '/account/google_login');
    expect(adapter.body, {
      'email': 'user@example.com',
      'idToken': 'google-id-token',
      'ip': '',
      'utm_source': '',
      'uuid': 'device-ios',
      'product': 'bots',
      'platform': 'ios',
    });
    expect(adapter.options.headers['Authorization'], isNotEmpty);
    expect(session.token, 'business-token');
    expect(session.phone, '');
    expect(session.avatar, '');
    expect(session.email, 'user@example.com');
    expect((await create().restoreSession())?.uid, '42');
    final persisted = await const FlutterSecureStorage().readAll();
    expect(persisted.values.join(), contains('business-token'));
    expect(persisted.values.join(), isNot(contains('google-id-token')));
    await service.logout();
    expect(await store.read(), null);
  });

  test('移动端缺少设备标识时不授权、不请求账号接口', () async {
    service = create(deviceUuidProvider: (_) async => '  ');
    await expectLater(service.googleLogin(), throwsStateError);
    expect(provider.calls, 0);
    expect(adapter.calls, 0);
    expect(service.session, null);
  });

  test('Google登录透传渠道参数和ip，status=4给出重新授权提示', () async {
    adapter.response = {'status': 4};
    await expectLater(
      service.googleLogin(utmSource: 'demo', ip: '192.0.2.1'),
      throwsA(
        isA<AccountException>()
            .having((e) => e.status, 'status', 4)
            .having((e) => e.message, 'message', contains('重新授权')),
      ),
    );
    expect(adapter.body['utm_source'], 'demo');
    expect(adapter.body['ip'], '192.0.2.1');
    expect(adapter.body['uuid'], 'device-ios');
    expect(service.session, null);
    expect(await store.read(), null);
  });

  test('取消Google授权不调用业务接口，不覆盖现有会话', () async {
    await store.write(AccountSession.fromJson(googleSessionData()));
    await service.restoreSession();
    provider.error = const GoogleLoginException(
      'canceled',
      '已取消',
      cancelled: true,
    );
    await expectLater(
      service.googleLogin(),
      throwsA(
        isA<GoogleLoginException>().having(
          (e) => e.cancelled,
          'cancelled',
          true,
        ),
      ),
    );
    expect(adapter.calls, 0);
    expect(service.session?.token, 'business-token');
  });

  test('空Google凭证不会调用后端', () async {
    provider.proof = const GoogleIdentityProof(
      email: 'user@example.com',
      idToken: '',
    );
    await expectLater(
      service.googleLogin(),
      throwsA(isA<GoogleLoginException>()),
    );
    expect(adapter.calls, 0);
    expect(await store.read(), null);
  });

  test('Google登录失败和不合法账号响应不保存凭证', () async {
    for (final response in [
      {'status': 1104},
      {'status': 4},
      {'status': 3},
      {
        'status': 0,
        'data': {...googleSessionData(), 'token': ''},
      },
      {
        'status': 0,
        'data': {...googleSessionData(), 'product': 'rtvt'},
      },
      {
        'status': 0,
        'data': {...googleSessionData(), 'email': 'another@example.com'},
      },
      {
        'status': 0,
        'data': {...googleSessionData()}..remove('email'),
      },
      {'status': 0},
    ]) {
      adapter.response = response;
      await expectLater(
        service.googleLogin(),
        throwsA(anyOf(isA<AccountException>(), isA<ApiDecodeException>())),
      );
      expect(service.session, null);
      expect(await store.read(), null);
    }
    expect(
      const AccountException(3, AccountOperation.googleLogin).message,
      isNot(contains('验证码错误')),
    );
  });

  test('持久化失败不发布Google登录状态', () async {
    service = create(storage: FailingStore());
    await expectLater(service.googleLogin(), throwsStateError);
    expect(service.session, null);
  });

  test('授权窗口等待期间防止重复登录，页面取消后不提交凭证', () async {
    provider.pending = Completer<GoogleIdentityProof>();
    final token = CancelToken();
    final pending = service.googleLogin(cancelToken: token);
    await expectLater(service.googleLogin(), throwsStateError);
    token.cancel();
    provider.pending!.complete(provider.proof);
    await expectLater(pending, throwsA(isA<DioException>()));
    expect(adapter.calls, 0);
    expect(provider.calls, 1);
    provider.pending = null;
    await service.googleLogin();
    expect(service.session?.uid, '42');
  });

  test('缺少OAuth配置在打开原生SDK前报错，错误类型可读', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await expectLater(
      NativeGoogleIdentityProvider().authenticate('ios'),
      throwsA(
        isA<GoogleLoginException>().having(
          (e) => e.code,
          'code',
          'missing_server_client_id',
        ),
      ),
    );
    expect(
      googleSignInFailure(GoogleSignInExceptionCode.canceled).cancelled,
      true,
    );
    expect(
      googleSignInFailure(GoogleSignInExceptionCode.clientConfigurationError)
          .message,
      contains('Client ID'),
    );
  });
}
