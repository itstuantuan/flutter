import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/core/network/api_client.dart';

void main() {
  final signer = RequestSigner(
    product: 'rtvt',
    platform: 'ios',
    secretKey: 'test-key=',
    clock: () => DateTime.parse('2024-07-01T15:59:59.123+08:00'),
  );

  test('独立计算的签名向量：UTF-8、端口、UTC、排除查询参数', () {
    final headers = signer.headers(
      uri: Uri.parse('https://EXAMPLE.com:8443/api/login?x=1'),
      jsonBody: '{"phone":"中文+123"}',
    );
    expect(
      headers['Authorization'],
      'U4MFEZrhz502VMNwsFa+SN/V9YyDV7EzNZNyeP4thj0=',
    );
    expect(headers['X-TimeStamp'], '2024-07-01T07:59:59Z');
    expect(
      signer.headers(uri: Uri.parse('https://example.com'), jsonBody: '{}'),
      signer.headers(uri: Uri.parse('https://example.com/'), jsonBody: '{}'),
    );
  });

  test('实际发送字节与签名一致，并覆盖冲突头', () async {
    final dio = Dio();
    final adapter = CaptureAdapter();
    dio.httpClientAdapter = adapter;
    final client = ApiClient(
      baseUrl: 'https://example.com:8443/api',
      dio: dio,
      signer: signer,
    );
    await client.post<dynamic>(
      '/login',
      data: {'phone': '中文+123'},
      query: {'x': 1},
      options: Options(headers: {'authorization': 'old'}),
    );
    expect(utf8.decode(adapter.bytes), '{"phone":"中文+123"}');
    expect(
      adapter.options.headers['Authorization'],
      'U4MFEZrhz502VMNwsFa+SN/V9YyDV7EzNZNyeP4thj0=',
    );
    expect(
      adapter.options.headers.keys
          .where((key) => key.toLowerCase() == 'authorization')
          .length,
      1,
    );
    expect(adapter.options.followRedirects, false);
    expect(() => client.setToken('token'), throwsStateError);
    await expectLater(
      client.get<dynamic>('/login'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      client.post<dynamic>('/login', data: 'invalid'),
      throwsA(isA<DioException>()),
    );
    await client.post<dynamic>('/login', data: ' { "a": 1 } ');
    expect(utf8.decode(adapter.bytes), ' { "a": 1 } ');
  });

  test('配置缺失和签名错误码', () {
    expect(
      () => const RequestSigner(
        product: '',
        platform: '',
        secretKey: '',
      ).headers(uri: Uri.parse('https://example.com'), jsonBody: '{}'),
      throwsStateError,
    );
    for (final code in [1101, 1102, 1103, 1104]) {
      expect(signatureErrorMessage(code), isNotNull);
    }
    expect(signatureErrorMessage(0), isNull);
  });
}

class CaptureAdapter implements HttpClientAdapter {
  late RequestOptions options;
  List<int> bytes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    bytes = [];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
