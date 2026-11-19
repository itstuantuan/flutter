import 'dart:convert';
import 'dart:typed_data';

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
      return sessionHeaders(session);
    },
  );

  /// Freeze credentials for a device operation; never borrow a later login.
  factory ChatService.forSession(AccountSession session) => ChatService(
    client: ApiClient(baseUrl: AppEnv.apiBaseUrl),
    headers: () => sessionHeaders(session),
  );

  static Future<Map<String, String>> sessionHeaders(
    AccountSession session,
  ) async {
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
  }

  final ApiClient client;
  final Future<Map<String, String>> Function() headers;

  /// Some endpoints return an object, completions return a list, and ack has no data.
  Future<Object?> requestData(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Map<String, String> extraHeaders = const {},
  }) async {
    final body = await client.request<dynamic>(
      '/api/v1/chat$path',
      method: method,
      data: data,
      query: query,
      options: Options(
        headers: {...await headers(), ...extraHeaders},
        followRedirects: false,
      ),
      cancelToken: cancelToken,
    );
    if (body is! Map || body['code'] is! int) {
      throw const ChatException('服务返回了无效响应');
    }
    if (body['code'] != 0) {
      throw ChatException('请求失败（错误码 ${body['code']}）');
    }
    return body['data'];
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final result = await requestData(
      path,
      method: method,
      data: data,
      query: query,
      cancelToken: cancelToken,
    );
    if (result is! Map) throw const ChatException('服务响应缺少对象数据');
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> requestList(
    String path, {
    CancelToken? cancelToken,
  }) async {
    final result = await requestData(path, cancelToken: cancelToken);
    if (result is! List) throw const ChatException('服务响应缺少列表数据');
    return result
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<Map<String, dynamic>> uploadVoice(
    Uint8List bytes, {
    required bool wav,
    CancelToken? cancelToken,
  }) {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const ChatException('录音为空或超过20MB，请重新录制');
    }
    return request(
      '/attachments',
      method: 'POST',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: wav ? 'voice.wav' : 'voice.m4a',
          contentType: DioMediaType('audio', wav ? 'wav' : 'mp4'),
        ),
      }),
      cancelToken: cancelToken,
    );
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
      in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
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
