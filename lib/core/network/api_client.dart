import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'request_signer.dart';

export 'request_signer.dart';

export 'package:dio/dio.dart'
    show
        BaseOptions,
        CancelToken,
        Dio,
        DioException,
        DioExceptionType,
        FormData,
        Headers,
        InterceptorsWrapper,
        MultipartFile,
        Options,
        ProgressCallback,
        RequestOptions,
        Response;

/// 在 [Options.extra] 中设置该键为 `true`，可跳过全局 401 处理。
/// 典型场景：登录接口本身返回 401 时，不应触发“登录已过期”。
const kSkipUnauthorizedHandler = 'skipUnauthorizedHandler';

/// 全项目共用的客户端，地址由环境配置注入。
final api = ApiClient(
  baseUrl: AppEnv.apiBaseUrl,
  signer: RequestSigner(
    product: AppEnv.apiProduct,
    platform: AppEnv.apiPlatform,
    secretKey: AppEnv.apiSecretKey,
  ),
);

class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
    this.signer,
    this.onUnauthorized,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final signing = signer;
          if (signing == null) {
            handler.next(options);
            return;
          }
          try {
            if (options.method.toUpperCase() != 'POST') {
              throw ArgumentError('签名接口仅支持 POST 请求');
            }
            final body = options.data is String
                ? options.data as String
                : jsonEncode(options.data ?? <String, dynamic>{});
            // 校验传入的字符串确实是 JSON；保留其原始空白和字段顺序。
            jsonDecode(body);
            final headers = signing.headers(uri: options.uri, jsonBody: body);
            options.headers = {
              for (final entry in options.headers.entries)
                if (!headers.keys.any(
                  (name) => name.toLowerCase() == entry.key.toLowerCase(),
                ))
                  entry.key: entry.value,
              ...headers,
            };
            options.contentType = headers['Content-Type'];
            // 发送已签名的字节，避免 Dio 再次序列化或编码。
            options.data = utf8.encode(body);
            options.followRedirects = false;
            handler.next(options);
          } catch (error, stackTrace) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                stackTrace: stackTrace,
                message: '请求签名失败：$error',
              ),
            );
          }
        },
        onError: (error, handler) {
          final isUnauthorized = error.response?.statusCode == 401;
          final skip =
              error.requestOptions.extra[kSkipUnauthorizedHandler] == true;
          if (signer == null && isUnauthorized && !skip) {
            setToken(null);
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      // 不输出原始异常、完整 URI、请求头或响应体，避免凭证进入日志。
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[HTTP] ${options.method} ${options.uri.path}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[HTTP] ${response.requestOptions.method} '
              '${response.requestOptions.uri.path} HTTP=${response.statusCode}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '[HTTP] ${error.requestOptions.method} '
              '${error.requestOptions.uri.path} FAILED '
              'HTTP=${error.response?.statusCode ?? "无响应"} type=${error.type.name}',
            );
            handler.next(error);
          },
        ),
      );
    }
  }

  final Dio _dio;
  final RequestSigner? signer;

  /// token 失效（HTTP 401）时回调，可用于清理登录态、跳转登录页。
  /// 单个请求可通过 [kSkipUnauthorizedHandler] 跳过。
  final void Function()? onUnauthorized;

  /// 底层 Dio，供测试替换或进阶配置（如刷新 token 拦截器）。
  Dio get dio => _dio;

  /// 登录后设置，退出登录传 null。只保存在内存，不负责持久化。
  void setToken(String? token) {
    if (signer != null) {
      throw StateError('Authorization 用于请求签名，登录凭证字段需按业务接口文档配置');
    }
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// 返回完整响应体；不自动剥离 data 或判断业务 code。
  /// 网络和 HTTP 错误保留为 DioException，模型转换错误原样抛出。
  /// [method] 为空时沿用 [options] 中的 method（默认 GET），不会被静默覆盖。
  Future<T> request<T>(
    String path, {
    String? method,
    Map<String, dynamic>? query,
    Object? data,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _send(
      path,
      method: method,
      query: query,
      data: data,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    if (decode != null) return decode(response.data);

    final body = response.data;
    if (body is T) return body;
    if (body == null) {
      throw ApiDecodeException('接口 $path 返回空响应体，无法转换为 $T');
    }
    throw ApiDecodeException('接口 $path 返回 ${body.runtimeType}，无法转换为 $T');
  }

  /// 适用于 204 等无响应体的接口，忽略返回内容。
  Future<void> requestVoid(
    String path, {
    String? method,
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    await _send(
      path,
      method: method,
      query: query,
      data: data,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<dynamic>> _send(
    String path, {
    String? method,
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    if (_dio.options.baseUrl.isEmpty && !Uri.parse(path).hasScheme) {
      throw StateError('请在环境配置文件中填写 API_BASE_URL，并停止后重新运行应用');
    }
    final base = options ?? Options();
    return _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: method == null ? base : base.copyWith(method: method),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => request<T>(
    path,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
  );

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => request<T>(
    path,
    method: 'POST',
    data: data,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => request<T>(
    path,
    method: 'PUT',
    data: data,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => request<T>(
    path,
    method: 'PATCH',
    data: data,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  Future<T> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
  }) => request<T>(
    path,
    method: 'DELETE',
    data: data,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
  );
}

/// 响应体与期望类型不一致时抛出，用于尽早暴露接口契约问题。
class ApiDecodeException implements Exception {
  ApiDecodeException(this.message);

  final String message;

  @override
  String toString() => 'ApiDecodeException: $message';
}

/// 把 [DioException] 转成可直接展示给用户的中文提示。
extension DioExceptionUserMessage on DioException {
  String get userMessage {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请稍后重试';
      case DioExceptionType.transformTimeout:
        return '数据处理超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络后重试';
      case DioExceptionType.badCertificate:
        return '安全证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badResponse:
        final status = response?.statusCode;
        if (status != null) {
          if (status == 401) return '登录已过期，请重新登录';
          if (status == 403) return '没有权限访问该资源';
          if (status == 404) return '请求的资源不存在';
          if (status >= 500) return '服务器开小差了，请稍后重试';
          return '请求失败（HTTP $status）';
        }
        return '服务器返回异常';
      case DioExceptionType.unknown:
        return '请求失败，请稍后重试';
    }
  }
}
