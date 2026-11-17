import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ExplorationStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> value);
}

/// Event acknowledgements and ambiguous operation IDs are isolated by user and environment.
class SecureExplorationStore implements ExplorationStore {
  SecureExplorationStore({
    required String namespace,
    FlutterSecureStorage? storage,
  }) : _key = 'bots.exploration.v1.$namespace',
       _storage = storage ?? const FlutterSecureStorage();
  final String _key;
  final FlutterSecureStorage _storage;
  @override
  Future<Map<String, dynamic>> read() async {
    final raw = await _storage.read(key: _key);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> write(Map<String, dynamic> value) =>
      _storage.write(key: _key, value: jsonEncode(value));
}
