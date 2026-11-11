import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ExperienceStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

/// 独立的本地模拟体验，不与真实账号绑定。
class LocalExperienceStore implements ExperienceStore {
  final _storage = const FlutterSecureStorage();
  static const _key = 'viitor.mock-experience.v1';
  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> value) =>
      _storage.write(key: _key, value: jsonEncode(value));
}
