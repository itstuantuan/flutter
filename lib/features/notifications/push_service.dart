import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_env.dart';
import '../auth/account_service.dart';
import '../chat/chat_service.dart';
import 'push_binding_service.dart';

/// APNs permission/token bridge and account-scoped device registration.
class PushService extends ChangeNotifier {
  PushService({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('viitor/apns');
  final MethodChannel channel;
  String authorization = 'notDetermined';
  String? token;
  String? environment;
  PushBindingService? _binding;
  AccountService? _account;
  String? get syncError => _binding?.error;
  bool get syncing => _binding?.syncing ?? false;
  final _notifications = <Map<String, String>>[];
  final _received = <String>{};
  Map<String, String>? get pendingNotification => _notifications.firstOrNull;
  set pendingNotification(Map<String, String>? value) {
    if (value == null) {
      if (_notifications.isNotEmpty) _notifications.removeAt(0);
    } else {
      final id = value['notificationId'];
      if (id != null && !_received.add(id)) return;
      if (_received.length > 100) _received.remove(_received.first);
      _notifications.add(value);
    }
  }

  void attachAccount(AccountService account) {
    if (!supported || _binding != null) return;
    final session = account.session;
    if (session == null) return;
    _account = account;
    _binding = PushBindingService(
      account: account,
      session: session,
      service: ChatService.forSession(session),
      apiEnvironment: AppEnv.apiBaseUrl,
      onChanged: notifyListeners,
    );
    account.beforeLogout.add(_clearNotifications);
  }

  Future<void> _clearNotifications() async {
    _notifications.clear();
    _received.clear();
    await channel.invokeMethod<void>('clearNotifications');
  }

  void _synchronize({bool force = false}) {
    if (environment == null) return;
    unawaited(
      _binding?.synchronize(
        token: token,
        environment: environment,
        enabled: allowed,
        force: force,
      ),
    );
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool _readingNotification = false;
  Future<void> readNotification() async {
    if (!supported || _readingNotification) return;
    _readingNotification = true;
    try {
      // Drain the native cold-start queue as well as a live click. The native
      // side caps this queue at 32, and duplicate IDs are ignored locally.
      for (var i = 0; i < 32; i++) {
        final value = await channel.invokeMapMethod<String, String>(
          'takeNotification',
        );
        if (value == null) break;
        pendingNotification = value;
      }
      notifyListeners();
    } catch (_) {
      // Keep native pending notifications available when the bridge is not ready.
    } finally {
      _readingNotification = false;
    }
  }

  String? error;
  bool busy = false;
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get allowed =>
      ['authorized', 'provisional', 'ephemeral'].contains(authorization);
  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'registrationChanged') await refresh();
      if (call.method == 'notificationOpened') await readNotification();
    });
    await refresh();
    await readNotification();
  }

  Future<void> refresh() async {
    if (!supported) return;
    await _read('status', forceSync: true);
    if (allowed && token == null && error == null) await register();
  }

  Future<void> _read(String method, {bool forceSync = false}) async {
    try {
      final value = await channel.invokeMapMethod<String, dynamic>(method);
      authorization = value?['authorization'] as String? ?? 'notDetermined';
      final apnsEnvironment = value?['environment'] as String?;
      environment = {'sandbox', 'production'}.contains(apnsEnvironment)
          ? apnsEnvironment
          : null;
      final raw = value?['token'] as String?;
      token = raw == null || raw.isEmpty ? null : raw;
      final failure = value?['registrationError'] as String?;
      error = failure == null || failure.isEmpty ? null : failure;
      if (token != null && environment == null) {
        error ??= '无法确认 APNs 签名环境，设备尚未登记。';
      }
      _synchronize(force: forceSync);
    } catch (_) {
      error = '无法读取通知状态，请重试。';
    }
    notifyListeners();
  }

  Future<void> request() async {
    if (busy || !supported) return;
    busy = true;
    notifyListeners();
    await _read('requestPermission');
    busy = false;
    notifyListeners();
  }

  Future<void> register() async {
    if (!supported || !allowed) return;
    try {
      await channel.invokeMethod<void>('register');
    } catch (_) {
      error = '无法注册推送，请重试。';
      notifyListeners();
    }
  }

  Future<void> openSettings() async {
    try {
      await channel.invokeMethod<void>('openSettings');
    } catch (_) {
      error = '无法打开系统设置。';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _account?.beforeLogout.remove(_clearNotifications);
    _binding?.dispose();
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
