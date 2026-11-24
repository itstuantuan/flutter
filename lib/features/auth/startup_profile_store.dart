import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local introduction progress and preferred name; never authentication proof.
class StartupProfileStore {
  static const _key = 'bots.startup-profile.v2';
  final FlutterSecureStorage storage;
  const StartupProfileStore({this.storage = const FlutterSecureStorage()});
  Future<Map<String, dynamic>> read() async {
    final raw = await storage.read(key: _key);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> write(Map<String, dynamic> value) =>
      storage.write(key: _key, value: jsonEncode(value));

  /// Unowned legacy names/intro progress must never be assigned to an account.
  Future<Map<String, dynamic>> readUser(String userId) async {
    if (userId.isEmpty) throw ArgumentError('User ID is required');
    final root = await read();
    final user = (root['users'] as Map?)?[userId];
    if (user is Map) return Map<String, dynamic>.from(user);
    final registration = (root['registrationChats'] as Map?)?[userId];
    return {
      'registrationChat': ?registration,
      if (registration == 'done') 'introDone': true,
    };
  }

  Future<void> writeUser(String userId, Map<String, dynamic> value) async {
    if (userId.isEmpty) throw ArgumentError('User ID is required');
    final root = await read();
    await write({
      ...root,
      'users': {...?root['users'] as Map?, userId: value},
    });
  }

  Future<bool> hasSelectedInterests(String userId) async {
    final profile = await read();
    final selected = (profile['interestsByUser'] as Map?)?[userId];
    return selected is List && selected.isNotEmpty;
  }

  Future<void> saveSelectedInterests(String userId, List<String> values) async {
    if (values.isEmpty) throw ArgumentError('请选择至少一个兴趣');
    final profile = await read();
    await write({
      ...profile,
      'interestsByUser': {
        ...?profile['interestsByUser'] as Map?,
        userId: values.toSet().toList(),
      },
    });
  }

  Future<void> clear() => storage.delete(key: _key);
}
