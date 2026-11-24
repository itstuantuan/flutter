import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLanguage extends ChangeNotifier {
  AppLanguage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static final instance = AppLanguage();
  static const storageKey = 'pals.ui.language.v1';
  final FlutterSecureStorage _storage;
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> restore() async {
    try {
      final code = await _storage.read(key: storageKey);
      _locale = Locale(code == 'zh' ? 'zh' : 'en');
    } catch (_) {
      _locale = const Locale('en');
    }
    notifyListeners();
  }

  Future<void> select(String code) async {
    if (!['en', 'zh'].contains(code)) throw ArgumentError.value(code, 'code');
    if (_locale.languageCode == code) return;
    await _storage.write(key: storageKey, value: code);
    _locale = Locale(code);
    notifyListeners();
  }
}
