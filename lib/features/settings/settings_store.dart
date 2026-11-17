import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalUserProfile {
  const LocalUserProfile({this.name, this.avatar});
  final String? name;
  final Uint8List? avatar;
}

/// Local preferences are scoped by authenticated UID, independently of tokens.
class SettingsStore {
  const SettingsStore({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  String _key(String uid) => 'pals.settings.v1.${Uri.encodeComponent(uid)}';
  Future<Map<String, dynamic>> _read(String uid) async {
    final raw = await storage.read(key: _key(uid));
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<LocalUserProfile> profile(String uid) async {
    final data = await _read(uid);
    return LocalUserProfile(
      name: data['name'] as String?,
      avatar: data['avatar'] is String
          ? base64Decode(data['avatar'] as String)
          : null,
    );
  }

  Future<void> saveProfile(String uid, LocalUserProfile profile) async {
    final data = await _read(uid);
    await storage.write(
      key: _key(uid),
      value: jsonEncode({
        ...data,
        if (profile.name != null) 'name': profile.name,
        if (profile.avatar != null) 'avatar': base64Encode(profile.avatar!),
      }),
    );
  }

  Future<void> saveFeedback(String uid, Map<String, dynamic> draft) async {
    // A local draft is never presented as a successful server submission.
    await storage.write(key: '${_key(uid)}.feedback', value: jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> feedback(String uid) async {
    final raw = await storage.read(key: '${_key(uid)}.feedback');
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }
}
