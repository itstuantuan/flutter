import 'dart:convert';

import '../../core/config/app_env.dart';
import '../../core/network/api_client.dart';
import 'models/account_models.dart';
import 'auth_debug_log.dart';
import 'device_uuid.dart';
import 'google_identity.dart';
import 'session_store.dart';

export 'models/account_models.dart';
export 'session_store.dart';
export 'google_identity.dart';

final account = AccountService(
  client: ApiClient(
    baseUrl: AppEnv.accountBaseUrl,
    signer: RequestSigner(
      product: AppEnv.apiProduct,
      platform: AppEnv.apiPlatform,
      secretKey: AppEnv.apiSecretKey,
    ),
  ),
  store: SecureSessionStore(
    namespace:
        '${AppEnv.name}.${AppEnv.accountBaseUrl}.${AppEnv.apiProduct}.${AppEnv.apiPlatform}',
  ),
);

class AccountService {
  AccountService({
    required this.client,
    required this.store,
    DateTime Function()? clock,
    this.deviceUuidProvider = readDeviceUuid,
    GoogleIdentityProvider? googleIdentity,
  }) : _clock = clock ?? DateTime.now,
       googleIdentity = googleIdentity ?? NativeGoogleIdentityProvider();

  final ApiClient client;
  final SessionStore store;
  final GoogleIdentityProvider googleIdentity;
  final Future<String?> Function(String platform) deviceUuidProvider;
  final DateTime Function() _clock;
  final Map<String, DateTime> _nextSend = {};
  final Set<String> _sending = {};
  bool _sessionBusy = false;
  AccountSession? _session;
  bool testNewUser = false;

  Future<void> resetForNewUserTest() => _withSessionLock(() async {
    if (!AppEnv.enableTestTools) throw StateError('测试入口未启用');
    final storage = store;
    if (storage is! SecureSessionStore) throw StateError('不支持重置此存储');
    await storage.resetForNewUserTest();
    _session = null;
    testNewUser = false;
    _nextSend.clear();
  });

  Future<void> _consumeNewUserTest() async {
    final storage = store;
    testNewUser =
        AppEnv.enableTestTools &&
        storage is SecureSessionStore &&
        await storage.consumeNewUserTest();
  }

  /// 本地凭证，不代表服务器已验证 token 仍有效。
  AccountSession? get session => _session;

  /// Registration history survives logout; it must not be used for auth.
  Future<bool> hasCompletedRegistration() async {
    final storage = store;
    if (storage is RegistrationHistoryStore) {
      return (storage as RegistrationHistoryStore).hasCompletedRegistration();
    }
    return await storage.read() != null;
  }

  RequestSigner get _signer {
    final signer = client.signer;
    if (signer == null ||
        signer.secretKey.isEmpty ||
        signer.product.trim().isEmpty ||
        !{'ios', 'android', 'web'}.contains(signer.platform)) {
      throw StateError('请配置账号接口的产品、平台和对应签名密钥');
    }
    return signer;
  }

  static String normalizePhone(String phone) {
    final value = phone.trim();
    if (!RegExp(r'^[1-9][0-9]{0,2}-[0-9]+$').hasMatch(value)) {
      throw ArgumentError('手机号格式应为 国家区号-手机号码');
    }
    return value;
  }

  int resendSeconds(String phone) {
    final until = _nextSend[phone.trim()];
    if (until == null) return 0;
    final milliseconds = until.difference(_clock()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  Map<String, dynamic> _body(String phone, String ip) {
    final signer = _signer;
    return {
      'phone': phone,
      'ip': ip.trim(),
      'product': signer.product,
      'platform': signer.platform,
    };
  }

  Future<void> sendPhoneVerify({
    required String phone,
    String ip = '',
    String utmSource = '',
    String? lang,
    CancelToken? cancelToken,
  }) async {
    final normalized = normalizePhone(phone);
    final body = _body(normalized, ip);
    if (_sending.contains(normalized) || resendSeconds(normalized) > 0) {
      throw const AccountException(2, AccountOperation.sendCode);
    }
    _sending.add(normalized);
    try {
      await _post(
        '/account/send_phone_verify',
        {...body, 'utm_source': utmSource, 'lang': ?lang},
        AccountOperation.sendCode,
        cancelToken,
      );
      _nextSend[normalized] = _clock().add(const Duration(seconds: 60));
    } on AccountException catch (error) {
      if (error.status == 2) {
        _nextSend[normalized] = _clock().add(const Duration(seconds: 60));
      }
      rethrow;
    } finally {
      _sending.remove(normalized);
    }
  }

  Future<AccountSession> phoneVerifyLogin({
    required String phone,
    required String code,
    String ip = '',
    String? uuid,
    CancelToken? cancelToken,
  }) => _withSessionLock(() async {
    final normalized = normalizePhone(phone);
    final body = _body(normalized, ip);
    if (code.trim().isEmpty) throw ArgumentError('验证码不能为空');
    final deviceId = await _deviceUuid(uuid: uuid);
    final response = await _post(
      '/account/phone_verify_login',
      {
        ...body,
        'code': code.trim(),
        if (deviceId != null && deviceId.isNotEmpty) 'uuid': deviceId,
      },
      AccountOperation.login,
      cancelToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiDecodeException('登录成功响应缺少 data');
    }
    final result = AccountSession.fromJson(data);
    if (result.product != _signer.product ||
        result.platform != _signer.platform ||
        result.phone != normalized) {
      throw ApiDecodeException('登录响应的账号、产品或平台与请求不一致');
    }
    await store.write(result);
    await _consumeNewUserTest();
    _session = result;
    return result;
  });

  Future<String?> _deviceUuid({String? uuid}) async {
    final platform = _signer.platform;
    final value =
        (uuid ??
                (platform == 'web' ? null : await deviceUuidProvider(platform)))
            ?.trim();
    if (platform != 'web' && (value == null || value.isEmpty)) {
      throw StateError('无法获取设备标识，请稍后重试');
    }
    return value;
  }

  /// Google ID Token 仅用于向账号服务换取业务 token，不用于本地登录判定。
  Future<AccountSession> googleLogin({
    String ip = '',
    String utmSource = '',
    CancelToken? cancelToken,
  }) => _withSessionLock(() async {
    final signer = _signer;
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    final deviceId = await _deviceUuid();
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    AuthDebugLog.event('Google 原生授权 START');
    final proof = await googleIdentity.authenticate(signer.platform);
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    if (proof.email.trim().isEmpty || proof.idToken.isEmpty) {
      throw const GoogleLoginException(
        'missing_credential',
        'Google 未返回完整登录凭证',
      );
    }
    AuthDebugLog.event('Google 原生授权 OK，开始账号凭证交换');
    final response = await _post(
      '/account/google_login',
      {
        'email': proof.email,
        'idToken': proof.idToken,
        'ip': ip.trim(),
        'utm_source': utmSource,
        if (deviceId != null && deviceId.isNotEmpty) 'uuid': deviceId,
        'product': signer.product,
        'platform': signer.platform,
      },
      AccountOperation.googleLogin,
      cancelToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiDecodeException('Google 登录成功响应缺少 data');
    }
    final result = AccountSession.fromJson(data);
    if (result.product != signer.product ||
        result.platform != signer.platform ||
        result.email.toLowerCase() != proof.email.toLowerCase()) {
      throw ApiDecodeException('Google 登录响应的账号、产品或平台与请求不一致');
    }
    await store.write(result);
    await _consumeNewUserTest();
    _session = result;
    return result;
  });

  /// 启动时调用。恢复本地状态；服务器鉴权接口尚未提供。
  Future<AccountSession?> restoreSession() => _withSessionLock(() async {
    final restored = await store.read();
    if (restored != null &&
        (restored.product != _signer.product ||
            restored.platform != _signer.platform)) {
      await store.clear();
      _session = null;
    } else {
      _session = restored;
    }
    return _session;
  });

  /// 仅清除本地凭证；文档未提供服务端注销接口。
  Future<void> logout() => _withSessionLock(() async {
    await store.clear();
    _session = null;
  });

  Future<T> _withSessionLock<T>(Future<T> Function() operation) async {
    if (_sessionBusy) throw StateError('登录状态正在更新，请稍后重试');
    _sessionBusy = true;
    try {
      return await operation();
    } finally {
      _sessionBusy = false;
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
    AccountOperation operation,
    CancelToken? cancelToken,
  ) async {
    Map<String, dynamic> response;
    try {
      final raw = await client.post<dynamic>(
        path,
        data: body,
        cancelToken: cancelToken,
        options: Options(extra: {kSkipUnauthorizedHandler: true}),
      );
      AuthDebugLog.responseShape(path, raw);
      Object? decoded = raw;
      if (raw is String) {
        try {
          decoded = jsonDecode(raw);
        } on FormatException {
          throw ApiDecodeException('账号接口返回非 JSON 文本，详见响应结构日志');
        }
        AuthDebugLog.responseShape(path, decoded);
      }
      if (decoded is! Map<String, dynamic>) {
        throw ApiDecodeException('账号接口应返回 JSON 对象，实际为 ${decoded.runtimeType}');
      }
      response = decoded;
    } on DioException catch (error, stack) {
      AuthDebugLog.error('POST $path', error, stack);
      final data = error.response?.data;
      AuthDebugLog.responseShape(path, data);
      if (data is Map<String, dynamic> &&
          data['status'] is int &&
          data['status'] != 0) {
        AuthDebugLog.status(path, data['status'] as int, operation);
        throw AccountException(data['status'] as int, operation);
      }
      rethrow;
    }
    final status = response['status'];
    if (status is! int) throw ApiDecodeException('账号接口响应缺少有效的 status');
    AuthDebugLog.status(path, status, operation);
    if (status != 0) throw AccountException(status, operation);
    return response;
  }
}
