import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import 'models/account_models.dart';
import 'google_identity.dart';

/// 仅输出白名单诊断字段，不序列化请求、响应或原始异常内容。
abstract final class AuthDebugLog {
  static final entries = ValueNotifier<List<String>>([]);

  /// 仅传入固定事件名称或白名单字段，禁止传入原始请求及响应。
  static void event(String message) {
    if (!kDebugMode) return;
    final line = '[Auth] ${DateTime.now().toIso8601String()} $message';
    final updated = [...entries.value, line];
    entries.value = List.unmodifiable(
      updated.length > 80 ? updated.sublist(updated.length - 80) : updated,
    );
    debugPrint(line);
    developer.log(line, name: 'bots.auth');
  }

  static void responseShape(String path, Object? body) {
    if (!kDebugMode) return;
    if (body is Map) {
      const fields = ['status', 'code', 'data', 'message', 'msg', 'error'];
      final shape = fields
          .map((key) {
            if (!body.containsKey(key)) return '$key=missing';
            final value = body[key];
            // 仅状态字段允许输出短数字值，其他字段只记录类型。
            if ((key == 'status' || key == 'code') &&
                (value is int ||
                    (value is String &&
                        RegExp(r'^-?[0-9]{1,6}$').hasMatch(value)))) {
              return '$key=$value(${value.runtimeType})';
            }
            return '$key:type=${value.runtimeType}';
          })
          .join(', ');
      event('POST $path response object fields=${body.length} {$shape}');
    } else if (body is String) {
      event(
        'POST $path response String length=${body.length} '
        'looksLikeHtml=${body.trimLeft().startsWith("<")}',
      );
    } else {
      event('POST $path response type=${body.runtimeType}');
    }
  }

  static void status(String path, int status, AccountOperation operation) {
    if (!kDebugMode) return;
    final message = status == 0
        ? '成功'
        : AccountException(status, operation).message;
    event('POST $path status=$status $message');
  }

  static void error(String operation, Object error, StackTrace stack) {
    if (!kDebugMode) return;
    String detail;
    if (error is GoogleLoginException) {
      detail = 'Google code=${error.code} ${error.message}';
    } else if (error is AccountException) {
      detail = 'status=${error.status} ${error.message}';
    } else if (error is DioException) {
      detail =
          'HTTP=${error.response?.statusCode ?? "无响应"} '
          'type=${error.type.name} ${error.userMessage} '
          'cause=${error.error?.runtimeType ?? "none"}';
    } else if (error is PlatformException) {
      // message/details 可能含凭证或设备信息，只记录原生错误码。
      final code = error.code.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      detail = 'PlatformException code=$code（设备读取或安全存储失败）';
    } else if (error is ApiDecodeException) {
      detail = '接口响应格式错误：${error.message}';
    } else if (error is ArgumentError) {
      detail = '请求参数校验失败';
    } else if (error is StateError) {
      detail = '配置、设备标识或会话状态异常；具体提示见页面';
    } else {
      detail = 'type=${error.runtimeType}';
    }
    event('$operation FAILED $detail');
    debugPrintStack(label: '[Auth] $operation stack', stackTrace: stack);
  }
}
