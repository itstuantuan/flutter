import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import 'models/account_models.dart';

abstract interface class SessionStore {
  Future<AccountSession?> read();
  Future<void> write(AccountSession session);
  Future<void> clear();
}

/// 已完成注册的历史记录，与登录凭证的生命周期独立。
abstract interface class RegistrationHistoryStore {
  Future<bool> hasCompletedRegistration();
}

/// 移动端安全存储；Web 登录凭证使用 sessionStorage，注册记录持久保存。
class SecureSessionStore implements SessionStore, RegistrationHistoryStore {
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
  static const _historyWebOptions = WebOptions(useSessionStorage: false);

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

  String get _registrationKey => '$_key.registration-completed';

  @override
  Future<bool> hasCompletedRegistration() async {
    if (await _storage.read(
          key: _registrationKey,
          webOptions: _historyWebOptions,
        ) ==
        'true') {
      return true;
    }
    // Migrate users who signed in before the separate completion flag existed.
    // This is registration history, not proof that a token is still valid.
    if (await read() == null) return false;
    await _storage.write(
      key: _registrationKey,
      value: 'true',
      webOptions: _historyWebOptions,
    );
    return true;
  }

  @override
  Future<void> write(AccountSession session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    await _storage.write(
      key: _registrationKey,
      value: 'true',
      webOptions: _historyWebOptions,
    );
  }

  String get _testNewUserKey => '$_key.test-new-user';

  Future<void> resetForNewUserTest() async {
    await _storage.write(key: _testNewUserKey, value: 'true');
    await clear();
    await _storage.delete(
      key: _registrationKey,
      webOptions: _historyWebOptions,
    );
  }

  Future<bool> consumeNewUserTest() async {
    final enabled = await _storage.read(key: _testNewUserKey) == 'true';
    if (enabled) await _storage.delete(key: _testNewUserKey);
    return enabled;
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
