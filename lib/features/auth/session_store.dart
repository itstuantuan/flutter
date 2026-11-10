import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import 'models/account_models.dart';

abstract interface class SessionStore {
  Future<AccountSession?> read();
  Future<void> write(AccountSession session);
  Future<void> clear();
}

/// 移动端安全存储；Web 使用 sessionStorage，关闭浏览器会话后失效。
class SecureSessionStore implements SessionStore {
  SecureSessionStore({required String namespace, FlutterSecureStorage? storage})
    : _key = 'bots.account.session.$namespace',
      _storage =
          storage ??
          const FlutterSecureStorage(
            webOptions: WebOptions(useSessionStorage: true),
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<AccountSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) throw const FormatException();
      return AccountSession.fromJson(data);
    } on FormatException {
      await clear();
      return null;
    } on ApiDecodeException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AccountSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
