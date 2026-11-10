import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/auth/models/account_models.dart';
import 'package:bots/features/auth/auth_debug_log.dart';

void main() {
  test('记录业务状态和调用栈，不输出原始异常中的敏感字段', () {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() => debugPrint = original);
    AuthDebugLog.status(
      '/account/phone_verify_login',
      1104,
      AccountOperation.login,
    );
    AuthDebugLog.error(
      '登录',
      DioException(
        requestOptions: RequestOptions(
          path: '/account/phone_verify_login',
          data: {'code': 'secret-code'},
          headers: {'Authorization': 'secret-signature'},
        ),
        message: 'secret-token',
        error: StateError('secret-key'),
      ),
      StackTrace.current,
    );
    AuthDebugLog.error(
      '恢复',
      PlatformException(
        code: 'storage_error',
        message: 'secret-token',
        details: 'secret-key',
      ),
      StackTrace.current,
    );
    AuthDebugLog.responseShape('/account/send_phone_verify', {
      'code': 1104,
      'data': {'token': 'secret-token'},
      'message': 'secret-key',
    });
    final output = lines.join('\n');
    expect(output, contains('status=1104'));
    expect(output, contains('code=1104(int)'));
    expect(output, contains('status=missing'));
    expect(output, contains('请求签名无效'));
    expect(output, contains('storage_error'));
    expect(output, contains('auth_debug_log_test.dart'));
    expect(output, isNot(contains('secret-')));
  });
}
