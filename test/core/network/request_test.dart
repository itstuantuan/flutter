import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/core/network/request_controller.dart';

void main() {
  test('请求携带参数和 token，并支持模型转换和清除 token', () async {
    final dio = Dio();
    final client = ApiClient(baseUrl: 'https://example.com', dio: dio);
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(Response(requestOptions: options, data: {'id': 1}));
        },
      ),
    );
    client.setToken('test');
    final id = await client.post<int>(
      '/users',
      data: {'name': 'A'},
      query: {'page': 2},
      decode: (body) => body['id'] as int,
    );
    expect(id, 1);
    expect(requests.first.method, 'POST');
    expect(requests.first.data, {'name': 'A'});
    expect(requests.first.queryParameters, {'page': 2});
    expect(requests.first.headers['Authorization'], 'Bearer test');
    client.setToken(null);
    await client.get<dynamic>('/users');
    expect(requests.last.headers.containsKey('Authorization'), isFalse);
  });

  test('网络错误保持 DioException', () async {
    final dio = Dio();
    final client = ApiClient(baseUrl: 'https://example.com', dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );
    await expectLater(
      client.get<dynamic>('/users'),
      throwsA(isA<DioException>()),
    );
  });

  test('只采用最后一次请求结果', () async {
    final state = RequestController<int>();
    addTearDown(state.dispose);
    final old = Completer<int>();
    final latest = Completer<int>();
    final first = state.run((_) => old.future);
    final second = state.run((_) => latest.future);
    latest.complete(2);
    await second;
    old.complete(1);
    await first;
    expect(state.data, 2);
    expect(state.loading, isFalse);
  });

  test('错误存入状态，重新运行清除错误', () async {
    final state = RequestController<int>();
    addTearDown(state.dispose);
    await state.run((_) async => throw StateError('failed'));
    expect(state.error, isA<StateError>());
    expect(state.loading, isFalse);
    await state.run((_) async => 3);
    expect(state.error, isNull);
    expect(state.data, 3);
  });

  test('取消和销毁后忽略未完成结果', () async {
    final state = RequestController<int>();
    final pending = Completer<int>();
    final run = state.run((_) => pending.future);
    state.cancel();
    expect(state.loading, isFalse);
    state.dispose();
    pending.complete(1);
    await run;
    expect(state.data, isNull);
  });
}
