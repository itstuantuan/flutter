import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_env.dart';

/// 仅在一次登录期间持有，不写入本地存储或日志。
class GoogleIdentityProof {
  const GoogleIdentityProof({required this.email, required this.idToken});
  final String email;
  final String idToken;
}

class GoogleLoginException implements Exception {
  const GoogleLoginException(this.code, this.message, {this.cancelled = false});
  final String code;
  final String message;
  final bool cancelled;

  @override
  String toString() => 'GoogleLoginException($code): $message';
}

abstract interface class GoogleIdentityProvider {
  Future<GoogleIdentityProof> authenticate(String platform);
}

/// 原生 Google OAuth 身份凭证，不使用 Firebase Auth，也不申请额外 API scopes。
class NativeGoogleIdentityProvider implements GoogleIdentityProvider {
  static Future<void>? _initialization;
  static final _sdk = GoogleSignIn.instance;

  @override
  Future<GoogleIdentityProof> authenticate(String platform) async {
    validateConfiguration(platform);
    var initialized = false;
    try {
      await (_initialization ??= _sdk.initialize(
        clientId: platform == 'ios' ? AppEnv.googleIosClientId : null,
        serverClientId: AppEnv.googleServerClientId,
      ));
      initialized = true;
      final account = await _sdk.authenticate();
      final idToken = account.authentication.idToken;
      if (account.email.isEmpty || idToken == null || idToken.isEmpty) {
        throw const GoogleLoginException(
          'missing_credential',
          'Google 未返回完整的邮箱和 ID Token，请重新登录',
        );
      }
      return GoogleIdentityProof(email: account.email, idToken: idToken);
    } on GoogleSignInException catch (error) {
      throw googleSignInFailure(error.code);
    } finally {
      // 业务登录态由账号系统管理；清除 SDK 临时登录态，不撤销 Google 授权。
      if (initialized) {
        try {
          await _sdk.signOut();
        } catch (_) {
          // 清理失败不能掩盖原始登录结果；下次授权前仍由系统确认账号。
        }
      }
    }
  }

  static void validateConfiguration(String platform) {
    if (kIsWeb || !{'ios', 'android'}.contains(platform)) {
      throw const GoogleLoginException(
        'unsupported_platform',
        '此 Demo 的 Google 登录支持 iOS 和 Android，请在手机上测试',
      );
    }
    if ((platform == 'ios' && defaultTargetPlatform != TargetPlatform.iOS) ||
        (platform == 'android' &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw const GoogleLoginException(
        'platform_mismatch',
        '当前设备与 API_PLATFORM 配置不一致',
      );
    }
    final pattern = RegExp(r'^[a-zA-Z0-9-]+\.apps\.googleusercontent\.com$');
    if (!pattern.hasMatch(AppEnv.googleServerClientId)) {
      throw const GoogleLoginException(
        'missing_server_client_id',
        '请配置 GOOGLE_SERVER_CLIENT_ID（Google Web 类型的 OAuth Client ID）',
      );
    }
    if (platform == 'ios' && !pattern.hasMatch(AppEnv.googleIosClientId)) {
      throw const GoogleLoginException(
        'missing_ios_client_id',
        '请配置 GOOGLE_IOS_CLIENT_ID 并生成 iOS 回调配置',
      );
    }
  }
}

/// 仅使用 SDK 错误码，description/details 可能携带敏感凭证。
GoogleLoginException googleSignInFailure(GoogleSignInExceptionCode code) =>
    switch (code) {
      GoogleSignInExceptionCode.canceled => const GoogleLoginException(
        'canceled',
        'Google 登录已取消（若选完账号后自动取消，请检查 OAuth 配置）',
        cancelled: true,
      ),
      GoogleSignInExceptionCode.clientConfigurationError =>
        const GoogleLoginException(
          'clientConfigurationError',
          'Google 客户端配置错误，请检查 Client ID、iOS 回调和 Android 签名指纹',
        ),
      GoogleSignInExceptionCode.providerConfigurationError =>
        const GoogleLoginException(
          'providerConfigurationError',
          'Google 登录服务配置异常，请检查 OAuth 项目及登录服务是否可用',
        ),
      GoogleSignInExceptionCode.interrupted => const GoogleLoginException(
        'interrupted',
        'Google 登录被中断，请重试',
      ),
      GoogleSignInExceptionCode.uiUnavailable => const GoogleLoginException(
        'uiUnavailable',
        '无法打开 Google 登录窗口，请回到前台重试',
      ),
      _ => const GoogleLoginException(
        'google_sign_in_failed',
        'Google 授权失败，请检查网络和 OAuth 配置后重试',
      ),
    };
