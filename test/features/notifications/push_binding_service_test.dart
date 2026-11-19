import 'dart:async';
import 'dart:convert';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/account_service.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/notifications/push_binding_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_service_test.dart' show Adapter, jsonResponse;

class MemoryPushStore implements PushBindingStore {
  final values = <String, List<Map<String, dynamic>>>{};
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> read(String scope) async =>
      (jsonDecode(jsonEncode(values[scope] ?? [])) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  @override
  Future<void> write(String scope, List<Map<String, dynamic>> records) async {
    if (fail) throw StateError('storage unavailable');
    values[scope] = (jsonDecode(jsonEncode(records)) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class MemorySessionStore implements SessionStore {
  MemorySessionStore(this.value);
  AccountSession? value;
  @override
  Future<AccountSession?> read() async => value;
  @override
  Future<void> write(AccountSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

AccountSession sessionFor(String uid) => AccountSession(
  registered: 0,
  uid: uid,
  nick: '',
  avatar: '',
  phone: '',
  product: 'rtvt',
  platform: 'ios',
  token: 'private-token-$uid',
);

Future<AccountService> accountFor(String uid) async {
  final account = AccountService(
    client: ApiClient(
      baseUrl: 'https://account.test',
      signer: RequestSigner(
        product: 'rtvt',
        platform: 'ios',
        secretKey: 'test-secret',
      ),
    ),
    store: MemorySessionStore(sessionFor(uid)),
  );
  await account.restoreSession();
  return account;
}

ResponseBody failure(int code) => ResponseBody.fromString(
  jsonEncode({'code': code}),
  code,
  headers: {
    'content-type': ['application/json'],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountService account;
  late MemoryPushStore store;
  late List<RequestOptions> calls;
  late Future<ResponseBody> Function(RequestOptions) respond;
  var sequence = 0;
  final services = <PushBindingService>[];

  PushBindingService binding({
    String env = 'https://bots.test',
    Duration? timeout,
  }) {
    final session = account.session!;
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) async {
        calls.add(options);
        expect(options.headers['Authorization'], 'Bearer ${session.token}');
        return respond(options);
      });
    final service = PushBindingService(
      account: account,
      session: session,
      service: ChatService(
        client: ApiClient(baseUrl: env, dio: dio),
        headers: () async => {
          'Authorization': 'Bearer ${session.token}',
          'X-User-Id': session.uid,
        },
      ),
      apiEnvironment: env,
      store: store,
      requestTimeout: timeout ?? const Duration(seconds: 2),
      logoutTimeout: const Duration(milliseconds: 100),
    );
    services.add(service);
    return service;
  }

  setUp(() async {
    account = await accountFor('A');
    store = MemoryPushStore();
    calls = [];
    sequence = 0;
    respond = (options) async {
      if (options.method == 'DELETE') {
        return ResponseBody.fromString(
          '{"code":0,"data":null}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      }
      final data = options.data as Map;
      return jsonResponse({
        'deviceId': data['deviceToken'] ?? 'token-one',
        'bindingId': 'binding-${++sequence}',
        'enabled': data['enabled'],
        'environment': data['environment'] ?? 'production',
      });
    };
  });
  tearDown(() {
    for (final service in services) {
      service.dispose();
    }
    services.clear();
  });

  test('register, permission change, logout use the newest binding and credentials', () async {
    final service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    expect(calls.single.path, '/api/v1/chat/notifications/devices');
    expect(calls.single.data, {
      'deviceToken': 'token-one',
      'environment': 'production',
      'enabled': true,
    });
    expect(jsonEncode(store.values), isNot(contains('private-token')));
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: false,
      force: true,
    );
    expect(calls.last.method, 'PUT');
    expect(calls.last.headers['X-Device-Binding'], 'binding-1');
    final previous = respond;
    respond = (options) async {
      expect(account.session?.uid, 'A');
      return previous(options);
    };
    await account.logout();
    expect(calls.last.method, 'DELETE');
    expect(calls.last.headers['X-Device-Binding'], 'binding-2');
    expect(account.session, isNull);
    expect(account.logoutWarning, isNull);
    expect(store.values.values.expand((e) => e), isEmpty);
  });

  test('a cold launch without a fresh token can still disable the persisted binding', () async {
    var service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    service.dispose();
    service = binding();
    await service.synchronize(
      token: null,
      environment: 'production',
      enabled: false,
      force: true,
    );
    expect(calls.last.method, 'PUT');
    expect((calls.last.data as Map)['enabled'], false);
    expect(calls.last.headers['X-Device-Binding'], 'binding-1');
  });

  test(
    'serializes an in-flight registration and a new permission snapshot',
    () async {
      final gate = Completer<ResponseBody>();
      final entered = Completer<void>();
      final normal = respond;
      respond = (options) async {
        if (calls.length == 1) {
          entered.complete();
          return gate.future;
        }
        return normal(options);
      };
      final service = binding();
      final first = service.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      await entered.future;
      final second = service.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: false,
      );
      expect(calls.length, 1);
      gate.complete(
        jsonResponse({
          'deviceId': 'token-one',
          'bindingId': 'first',
          'enabled': true,
          'environment': 'production',
        }),
      );
      await Future.wait([first, second]);
      expect(calls.map((e) => e.method), ['POST', 'PUT']);
      expect(calls.last.headers['X-Device-Binding'], 'first');
      expect(store.values.values.single.single['enabled'], false);
    },
  );

  test('token rotation keeps failed cleanup, registers new token and recovers on restart', () async {
    var service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    final normal = respond;
    respond = (options) async =>
        options.method == 'DELETE' ? failure(503) : normal(options);
    await service.synchronize(
      token: 'token-two',
      environment: 'production',
      enabled: true,
    );
    expect(service.error, isNotNull);
    expect(store.values.values.single.length, 2);
    expect(store.values.values.single.first['pending'], true);
    service.dispose();
    respond = normal;
    service = binding();
    await service.synchronize(
      token: 'token-two',
      environment: 'production',
      enabled: true,
      force: true,
    );
    expect(service.error, isNull);
    expect(store.values.values.single.single['token'], 'token-two');
  });

  test(
    'late registration cannot write a binding after account changes',
    () async {
      final gate = Completer<ResponseBody>();
      final entered = Completer<void>();
      respond = (_) {
        entered.complete();
        return gate.future;
      };
      final service = binding();
      final pending = service.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      await entered.future;
      await account.store.write(sessionFor('B'));
      await account.restoreSession();
      gate.complete(
        jsonResponse({
          'deviceId': 'token-one',
          'bindingId': 'late-A',
          'enabled': true,
          'environment': 'production',
        }),
      );
      await pending;
      expect(store.values.values.single.single['bindingId'], isNull);
      expect(account.session!.uid, 'B');
      expect(calls.single.headers['X-User-Id'], 'A');
    },
  );

  test(
    'API environment, account and APNs environment have separate ledgers',
    () async {
      final first = binding();
      await first.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      first.dispose();
      final sandbox = binding();
      await sandbox.synchronize(
        token: 'token-one',
        environment: 'sandbox',
        enabled: true,
      );
      sandbox.dispose();
      final secondApi = binding(env: 'https://bots.other');
      await secondApi.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      secondApi.dispose();
      await account.store.write(sessionFor('B'));
      await account.restoreSession();
      await binding().synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      expect(store.values.length, 4);
      expect(calls.every((e) => e.method == 'POST'), true);
    },
  );

  test('preference conflict registers current owner again; logout conflict is not success', () async {
    final service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    final normal = respond;
    respond = (options) async =>
        options.method == 'PUT' || options.method == 'DELETE'
        ? failure(409)
        : normal(options);
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: false,
    );
    expect(calls.map((e) => e.method), ['POST', 'PUT', 'POST']);
    await account.logout();
    expect(account.session, isNull);
    expect(account.logoutWarning, isNotNull);
    expect(store.values.values.single.single['pending'], true);
  });

  test(
    'logout timeout is bounded, retains the journal, and clears credentials',
    () async {
      final service = binding(timeout: const Duration(milliseconds: 15));
      await service.synchronize(
        token: 'token-one',
        environment: 'production',
        enabled: true,
      );
      final gate = Completer<ResponseBody>();
      respond = (_) => gate.future;
      final clock = Stopwatch()..start();
      await account.logout();
      expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
      expect(account.session, isNull);
      expect(account.logoutWarning, isNotNull);
      expect(store.values.values.single.single['pending'], true);
      gate.complete(
        ResponseBody.fromString(
          '{"code":0,"data":null}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
    },
  );

  test('logout drains an in-flight registration before deleting its returned binding', () async {
    final gate = Completer<ResponseBody>();
    final entered = Completer<void>();
    final normal = respond;
    respond = (options) async {
      if (options.method == 'POST') {
        entered.complete();
        return gate.future;
      }
      return normal(options);
    };
    final service = binding();
    final registration = service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    await entered.future;
    final logout = account.logout();
    gate.complete(
      jsonResponse({
        'deviceId': 'token-one',
        'bindingId': 'final-binding',
        'enabled': true,
        'environment': 'production',
      }),
    );
    await Future.wait([registration, logout]);
    expect(calls.map((e) => e.method), ['POST', 'DELETE']);
    expect(calls.last.headers['X-Device-Binding'], 'final-binding');
    expect(account.logoutWarning, isNull);
  });

  test('a timed-out registration is reconciled after restart without losing its token journal', () async {
    final gate = Completer<ResponseBody>();
    final normal = respond;
    respond = (_) => gate.future;
    var service = binding(timeout: const Duration(milliseconds: 15));
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    expect(service.error, isNotNull);
    expect(store.values.values.single.single['bindingId'], isNull);
    service.dispose();
    respond = normal;
    service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    gate.complete(
      jsonResponse({
        'deviceId': 'token-one',
        'bindingId': 'obsolete',
        'enabled': true,
        'environment': 'production',
      }),
    );
    expect(store.values.values.single.single['bindingId'], 'binding-1');
    await account.logout();
    expect(calls.last.headers['X-Device-Binding'], 'binding-1');
  });

  test('failed registration is journaled before network; storage failure sends nothing', () async {
    respond = (_) async => failure(401);
    final service = binding();
    await service.synchronize(
      token: 'token-one',
      environment: 'production',
      enabled: true,
    );
    expect(service.error, contains('登录已过期'));
    expect(store.values.values.single.single['token'], 'token-one');
    service.dispose();
    calls.clear();
    store = MemoryPushStore()..fail = true;
    await binding().synchronize(
      token: 'token-two',
      environment: 'production',
      enabled: true,
    );
    expect(calls, isEmpty);
  });
}
