import 'package:json_annotation/json_annotation.dart';

import '../../../core/network/api_client.dart';

part 'account_models.g.dart';

enum AccountOperation { sendCode, login, googleLogin }

class AccountException implements Exception {
  const AccountException(this.status, this.operation);

  final int status;
  final AccountOperation operation;

  String get message =>
      signatureErrorMessage(status) ??
      switch (status) {
        1 => '请求参数错误，请检查输入',
        2 =>
          operation == AccountOperation.sendCode
              ? '验证码发送过于频繁，请稍后重试'
              : '登录尝试过于频繁，请一分钟后重试',
        3 when operation == AccountOperation.login => '验证码错误，请重新输入',
        4 when operation == AccountOperation.googleLogin =>
          'Google 登录凭证无效或已过期，请重新授权',
        16 when operation == AccountOperation.sendCode => '今日验证码发送次数已达上限',
        17 when operation == AccountOperation.sendCode => '该手机号暂时无法接收验证码',
        -1 => '服务暂时不可用，请稍后重试',
        _ => '请求失败（错误码：$status）',
      };

  @override
  String toString() => 'AccountException: $message';
}

/// token 不进入 toString；registered=1 才表示首次注册。
@JsonSerializable(checked: true)
class AccountSession {
  const AccountSession({
    required this.registered,
    required this.uid,
    required this.nick,
    required this.avatar,
    required this.phone,
    required this.product,
    required this.platform,
    required this.token,
    this.email = '',
  });

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final registered = json['registered'];
    if (registered is! int || (registered != 0 && registered != 1)) {
      throw ApiDecodeException('登录响应字段 registered 格式错误');
    }
    try {
      final session = _$AccountSessionFromJson(json);
      session._validate();
      return session;
    } on ApiDecodeException {
      rethrow;
    } catch (_) {
      throw ApiDecodeException('登录响应字段格式错误');
    }
  }

  final int registered;
  bool get isNewUser => registered == 1;
  final String uid;
  final String nick;
  @JsonKey(defaultValue: '')
  final String avatar;
  @JsonKey(defaultValue: '')
  final String phone;
  final String product;
  final String platform;
  final String token;
  @JsonKey(defaultValue: '')
  final String email;

  void _validate() {
    for (final field in {
      'uid': uid,
      'product': product,
      'platform': platform,
      'token': token,
    }.entries) {
      if (field.value.isEmpty) {
        throw ApiDecodeException('登录响应字段 ${field.key} 格式错误');
      }
    }
  }

  /// 含敏感凭证，仅用于持久化，禁止打印。
  Map<String, dynamic> toJson() => _$AccountSessionToJson(this);
}
