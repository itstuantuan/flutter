import 'package:dio/dio.dart';

import '../config/app_env.dart';

export 'package:dio/dio.dart'
    show CancelToken, DioException, FormData, MultipartFile, Options;

/// 全项目共用的客户端，地址由环境配置注入。
final api = ApiClient(baseUrl: AppEnv.apiBaseUrl);

class ApiClient {
  ApiClient({required String baseUrl, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );
  }

  final Dio _dio;

  /// 登录后设置，退出登录传 null。只保存在内存，不负责持久化。
  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// 返回完整响应体；不自动剥离 data 或判断业务 code。
  /// 网络和 HTTP 错误保留为 DioException，模型转换错误原样抛出。
  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? data,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (_dio.options.baseUrl.isEmpty && !Uri.parse(path).hasScheme) {
      throw StateError('请在环境配置文件中填写 API_BASE_URL，并停止后重新运行应用');
    }
    final response = await _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: (options ?? Options()).copyWith(method: method),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return decode != null ? decode(response.data) : response.data as T;
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
  }) => request<T>(
    path,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
  );

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    T Function(dynamic body)? decode,
    Options? options,
    CancelToken? cancelToken,
  }) => request<T>(
    path,
    method: 'POST',
    data: data,
    query: query,
    decode: decode,
    options: options,
    cancelToken: cancelToken,
  );
}
