import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';

Map<String, dynamic> loginData({
  String platform = 'android',
  int registered = 0,
}) => {
  'registered': registered,
  'uid': '1001139',
  'nick': 'User1001139',
  'avatar': '',
  'phone': '86-15010887212',
  'product': 'rtvt',
  'platform': platform,
  'token': 'test-token',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late StubAdapter adapter;
  late AccountService service;
  late SecureSessionStore store;

  AccountService create({String platform = 'android', SessionStore? storage}) {
    final dio = Dio()..httpClientAdapter = adapter;
    return AccountService(
      client: ApiClient(
        baseUrl: 'https://account-api.ilivedata.com',
        dio: dio,
        signer: RequestSigner(
          product: 'rtvt',
          platform: platform,
          secretKey: 'test-secret',
          clock: () => now,
        ),
      ),
      store: storage ?? store,
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime.utc(2024, 7, 1);
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureSessionStore(namespace: 'test');
    adapter = StubAdapter();
    service = create();
  });

  test('支持后端新增的 bots 产品，签名头与请求体保持一致', () async {
    final dio = Dio()..httpClientAdapter = adapter;
    final bots = AccountService(
      client: ApiClient(
        baseUrl: 'https://account-api.ilivedata.com',
        dio: dio,
        signer: const RequestSigner(
          product: 'bots',
          platform: 'ios',
          secretKey: 'test-key',
        ),
      ),
      store: store,
    );
    await bots.sendPhoneVerify(phone: '86-15010887212');
    expect(adapter.body['product'], 'bots');
    expect(adapter.body['platform'], 'ios');
    expect(adapter.options.headers['X-Product'], 'bots');
    expect(adapter.options.headers['X-Platform'], 'ios');
  });

  test('兼容文本形式JSON，非JSON响应给出明确错误', () async {
    adapter.response = '{"status":0}';
    await service.sendPhoneVerify(phone: '86-15010887212');
    adapter.response = '<html>gateway error</html>';
    await expectLater(
      service.sendPhoneVerify(phone: '86-15010887213'),
      throwsA(
        isA<ApiDecodeException>().having(
          (e) => e.message,
          'message',
          contains('非 JSON'),
        ),
      ),
    );
  });

  test('发送字段和签名一致；同号冷却60秒，不影响其他号码', () async {
    await service.sendPhoneVerify(
      phone: ' 86-15010887212 ',
      ip: '192.0.2.1',
      utmSource: 'test',
      lang: 'en',
    );
    expect(adapter.options.uri.path, '/account/send_phone_verify');
    expect(adapter.body, {
      'phone': '86-15010887212',
      'ip': '192.0.2.1',
      'product': 'rtvt',
      'platform': 'android',
      'utm_source': 'test',
      'lang': 'en',
    });
    expect(adapter.options.headers['X-Product'], adapter.body['product']);
    expect(adapter.options.headers['X-Platform'], adapter.body['platform']);
    expect(adapter.options.headers['Authorization'], isNotEmpty);
    expect(service.resendSeconds('86-15010887212'), 60);
    await expectLater(
      service.sendPhoneVerify(phone: '86-15010887212', ip: '192.0.2.1'),
      throwsA(isA<AccountException>().having((e) => e.status, 'status', 2)),
    );
    expect(adapter.calls, 1);
    await service.sendPhoneVerify(phone: '86-15010887213', ip: '192.0.2.1');
    now = now.add(const Duration(seconds: 59, milliseconds: 1));
    expect(service.resendSeconds('86-15010887212'), 1);
    now = now.add(const Duration(seconds: 1));
    await service.sendPhoneVerify(phone: '86-15010887212', ip: '192.0.2.1');
    expect(adapter.body.containsKey('lang'), false);
  });

  test('同号发送中阻止重复请求；失败后释放', () async {
    final gate = Completer<void>();
    adapter.gate = gate.future;
    final pending = service.sendPhoneVerify(
      phone: '86-15010887212',
      ip: '192.0.2.1',
    );
    await expectLater(
      service.sendPhoneVerify(phone: '86-15010887212', ip: '192.0.2.1'),
      throwsA(isA<AccountException>()),
    );
    adapter.response = {'status': 16};
    gate.complete();
    await expectLater(pending, throwsA(isA<AccountException>()));
    expect(service.resendSeconds('86-15010887212'), 0);
    adapter.response = {'status': 0};
    await service.sendPhoneVerify(phone: '86-15010887212', ip: '192.0.2.1');
  });

  test('发送错误、签名错误和HTTP错误中的业务status', () async {
    for (final status in [1, 2, 16, 17, 1101, 1102, 1103, 1104, 99]) {
      service = create();
      adapter.response = {'status': status};
      adapter.httpStatus = status == 1104 ? 403 : 200;
      await expectLater(
        service.sendPhoneVerify(phone: '86-15010887212', ip: '192.0.2.1'),
        throwsA(
          isA<AccountException>().having((e) => e.status, 'status', status),
        ),
      );
      expect(service.resendSeconds('86-15010887212'), status == 2 ? 60 : 0);
    }
  });

  test('登录保留验证码前导零，保存恢复和退出；首次注册语义', () async {
    adapter.response = {'status': 0, 'data': loginData(registered: 1)};
    final session = await service.phoneVerifyLogin(
      phone: '86-15010887212',
      code: '001234',
      ip: '192.0.2.1',
      uuid: 'device-id',
    );
    expect(adapter.options.uri.path, '/account/phone_verify_login');
    expect(adapter.body['code'], '001234');
    expect(adapter.body['uuid'], 'device-id');
    expect(session.isNewUser, true);
    expect(session.toString(), isNot(contains('test-token')));
    expect(service.session?.token, 'test-token');
    final restarted = create();
    expect((await restarted.restoreSession())?.uid, '1001139');
    await restarted.logout();
    expect(restarted.session, null);
    expect(await create().restoreSession(), null);
  });

  test('移动端自动读取uuid，ip默认空；Web不传uuid', () async {
    for (final platform in ['ios', 'android']) {
      final dio = Dio()..httpClientAdapter = adapter;
      service = AccountService(
        client: ApiClient(
          baseUrl: 'https://account-api.ilivedata.com',
          dio: dio,
          signer: RequestSigner(
            product: 'rtvt',
            platform: platform,
            secretKey: 'test',
          ),
        ),
        store: store,
        deviceUuidProvider: (requestedPlatform) async {
          expect(requestedPlatform, platform);
          return 'device-$platform';
        },
      );
      adapter.response = {'status': 0, 'data': loginData(platform: platform)};
      await service.phoneVerifyLogin(phone: '86-15010887212', code: '001234');
      expect(adapter.body['uuid'], 'device-$platform');
      expect(adapter.body['ip'], '');
    }
    service = create(platform: 'web');
    adapter.response = {'status': 0};
    await service.sendPhoneVerify(phone: '86-15010887212');
    expect(adapter.body['ip'], '');
    adapter.response = {'status': 0, 'data': loginData(platform: 'web')};
    final session = await service.phoneVerifyLogin(
      phone: '86-15010887212',
      code: '1234',
    );
    expect(adapter.body.containsKey('uuid'), false);
    expect(session.isNewUser, false);
    await expectLater(
      service.sendPhoneVerify(phone: '15010887212'),
      throwsArgumentError,
    );
    await expectLater(
      service.phoneVerifyLogin(phone: '86-15010887212', code: ''),
      throwsArgumentError,
    );
  });

  test('设备标识读取失败时不发送登录请求', () async {
    final dio = Dio()..httpClientAdapter = adapter;
    service = AccountService(
      client: ApiClient(
        baseUrl: 'https://account-api.ilivedata.com',
        dio: dio,
        signer: const RequestSigner(
          product: 'rtvt',
          platform: 'android',
          secretKey: 'test',
        ),
      ),
      store: store,
      deviceUuidProvider: (_) async => null,
    );
    await expectLater(
      service.phoneVerifyLogin(phone: '86-15010887212', code: '1234'),
      throwsStateError,
    );
    expect(adapter.calls, 0);
  });

  test('登录业务失败或异常响应不覆盖原凭证', () async {
    final old = AccountSession.fromJson(loginData());
    await store.write(old);
    await service.restoreSession();
    for (final status in [1, 2, 3, -1, 1104]) {
      adapter.response = {'status': status};
      await expectLater(
        service.phoneVerifyLogin(
          phone: '86-15010887212',
          code: '1234',
          ip: '192.0.2.1',
          uuid: 'device',
        ),
        throwsA(
          isA<AccountException>().having((e) => e.status, 'status', status),
        ),
      );
    }
    for (final response in [
      <String, dynamic>{},
      {'status': '0'},
      {'status': 0},
      {
        'status': 0,
        'data': {...loginData(), 'token': ''},
      },
      {
        'status': 0,
        'data': {...loginData(), 'phone': '86-15010887213'},
      },
    ]) {
      adapter.response = response;
      await expectLater(
        service.phoneVerifyLogin(
          phone: '86-15010887212',
          code: '1234',
          ip: '192.0.2.1',
          uuid: 'device',
        ),
        throwsA(isA<ApiDecodeException>()),
      );
    }
    expect(service.session?.token, 'test-token');
    expect((await store.read())?.token, 'test-token');
  });

  test('损坏缓存被清除，跨产品平台缓存不会恢复', () async {
    FlutterSecureStorage.setMockInitialValues({
      'bots.account.session.test': '{broken',
    });
    expect(await service.restoreSession(), null);
    await store.write(AccountSession.fromJson(loginData(platform: 'web')));
    expect(await service.restoreSession(), null);
    expect(await store.read(), null);
  });

  test('存储失败不发布已登录状态', () async {
    service = create(storage: FailingStore());
    adapter.response = {'status': 0, 'data': loginData()};
    await expectLater(
      service.phoneVerifyLogin(
        phone: '86-15010887212',
        code: '1234',
        ip: '192.0.2.1',
        uuid: 'device',
      ),
      throwsStateError,
    );
    expect(service.session, null);
  });

  test('并发登录与退出不会竞争写入凭证', () async {
    final gate = Completer<void>();
    adapter.gate = gate.future;
    adapter.response = {'status': 0, 'data': loginData()};
    final pending = service.phoneVerifyLogin(
      phone: '86-15010887212',
      code: '1234',
      ip: '192.0.2.1',
      uuid: 'device',
    );
    await expectLater(service.logout(), throwsStateError);
    gate.complete();
    await pending;
    await service.logout();
    expect(await store.read(), null);
  });
}

class FailingStore implements SessionStore {
  @override
  Future<AccountSession?> read() async => null;
  @override
  Future<void> write(AccountSession session) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> clear() async {}
}

class StubAdapter implements HttpClientAdapter {
  Object? response = {'status': 0};
  int httpStatus = 200;
  int calls = 0;
  Future<void>? gate;
  late RequestOptions options;
  late Map<String, dynamic> body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    this.options = options;
    final bytes = <int>[];
    await for (final chunk in stream!) {
      bytes.addAll(chunk);
    }
    body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    await gate;
    return ResponseBody.fromString(
      jsonEncode(response),
      httpStatus,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
