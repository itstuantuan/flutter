import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_env.dart';
import '../../core/network/api_client.dart';
import '../auth/account_service.dart';
import '../auth/device_uuid.dart';

/// Bots uses company login credentials, independently of account API signing.
class ChatService {
  ChatService({required this.client, required this.headers});

  factory ChatService.authenticated(AccountService account) => ChatService(
    client: ApiClient(baseUrl: AppEnv.apiBaseUrl),
    headers: () async {
      final session = account.session;
      if (session == null) throw const ChatException('请先登录');
      final channel = switch (session.platform) {
        'ios' => '300',
        'android' => '200',
        _ => throw const ChatException('当前平台尚未配置聊天鉴权'),
      };
      final device = await readDeviceUuid(session.platform);
      return {
        'Authorization': 'Bearer ${session.token}',
        'X-User-Id': session.uid,
        'X-Device-ID': device!,
        'X-Channel': channel,
      };
    },
  );

  final ApiClient client;
  final Future<Map<String, String>> Function() headers;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    CancelToken? cancelToken,
  }) async {
    final body = await client.request<dynamic>(
      '/api/v1/chat$path',
      method: method,
      data: data,
      options: Options(headers: await headers(), followRedirects: false),
      cancelToken: cancelToken,
    );
    if (body is! Map || body['code'] is! int) {
      throw const ChatException('聊天服务返回了无效响应');
    }
    if (body['code'] != 0) {
      throw ChatException('聊天请求失败（错误码 ${body['code']}）');
    }
    if (body['data'] is! Map) {
      throw const ChatException('聊天服务响应缺少数据');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Stream<SseEvent> subscribe(String sessionId, CancelToken cancel) async* {
    final response = await client.request<ResponseBody>(
      '/api/v1/chat/sessions/${Uri.encodeComponent(sessionId)}/stream',
      method: 'GET',
      options: Options(
        headers: {...await headers(), 'Accept': 'text/event-stream'},
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 70),
        followRedirects: false,
      ),
      cancelToken: cancel,
    );
    if (!(response.headers['content-type']?.join(',') ?? '')
        .toLowerCase()
        .contains('text/event-stream')) {
      throw const ChatException('聊天流返回格式错误');
    }
    yield* decodeSse(response.stream);
  }
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
}

class SseEvent {
  const SseEvent(this.type, this.data);
  final String type, data;
}

/// Decode UTF-8 across packet boundaries and dispatch only complete SSE frames.
Stream<SseEvent> decodeSse(Stream<List<int>> bytes) async* {
  var type = 'message';
  final data = <String>[];
  await for (final line
      in bytes.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(type, data.join('\n'));
      type = 'message';
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    var value = separator < 0 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') type = value;
    if (field == 'data') data.add(value);
  }
}
