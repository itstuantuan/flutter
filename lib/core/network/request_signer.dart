import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 密钥按 UTF-8 原文使用，不做 Base64 解码。
class RequestSigner {
  const RequestSigner({
    required this.product,
    required this.platform,
    required this.secretKey,
    this.clock = DateTime.now,
  });

  final String product;
  final String platform;
  final String secretKey;
  final DateTime Function() clock;

  Map<String, String> headers({required Uri uri, required String jsonBody}) {
    if (product.isEmpty || platform.isEmpty || secretKey.isEmpty) {
      throw StateError('请配置 API_PRODUCT、API_PLATFORM 和 API_SECRET_KEY');
    }
    final now = clock().toUtc();
    final timestamp = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ).toIso8601String().replaceFirst('.000Z', 'Z');
    final host = uri.hasPort
        ? '${uri.host}:${uri.port}'.toLowerCase()
        : uri.host.toLowerCase();
    final stringToSign = [
      'POST',
      host,
      uri.path.isEmpty ? '/' : uri.path,
      sha256.convert(utf8.encode(jsonBody)).toString(),
      'X-Product:$product',
      'X-Platform:$platform',
      'X-TimeStamp:$timestamp',
    ].join('\n');
    final signature = Hmac(
      sha256,
      utf8.encode(secretKey),
    ).convert(utf8.encode(stringToSign));
    return {
      'Content-Type': 'application/json;charset=UTF-8',
      'Accept': 'application/json;charset=UTF-8',
      'X-Product': product,
      'X-Platform': platform,
      'X-TimeStamp': timestamp,
      'Authorization': base64Encode(signature.bytes),
    };
  }
}

/// 响应字段结构需由具体业务接口解析，再传入错误码获取提示。
String? signatureErrorMessage(Object? code) => switch (code.toString()) {
  '1101' => 'HTTP请求头缺少参数',
  '1102' => 'HTTP请求头参数错误',
  '1103' => '请求签名已过期，请检查设备时间后重试',
  '1104' => '请求签名无效',
  _ => null,
};
