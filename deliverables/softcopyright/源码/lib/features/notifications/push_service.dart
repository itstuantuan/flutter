import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// APNs 设备状态；尚未提供后端登记协议，不会自动上传 token。
class PushService extends ChangeNotifier {
  PushService({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('viitor/apns');
  final MethodChannel channel;
  String authorization = 'notDetermined';
  String? token;
  Map<String, String>? pendingNotification;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> readNotification() async {
    if (!supported) return;
    try {
      final value = await channel.invokeMapMethod<String, String>(
        'takeNotification',
      );
      if (value != null) pendingNotification = value;
      notifyListeners();
    } catch (_) {
      /* Routing remains pending until backend integration. */
    }
  }

  Future<bool> scheduleDemo() async {
    if (!kDebugMode || !supported || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await channel.invokeMethod<void>('scheduleDemo');
      return true;
    } on PlatformException catch (e) {
      error = e.message ?? '本地通知安排失败，请重试。';
      return false;
    } on MissingPluginException {
      error = '本地通知原生方法未启用，请检查 Runner 的 Debug 编译配置。';
      return false;
    } catch (_) {
      error = '本地通知调用失败，请重试。';
      return false;
    } finally {
      busy = false;
      notifyListeners();
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
    if (supported && allowed) await register();
  }

  Future<void> refresh() async {
    if (!supported) return;
    await _read('status');
  }

  Future<void> _read(String method) async {
    try {
      final value = await channel.invokeMapMethod<String, dynamic>(method);
      authorization = value?['authorization'] as String? ?? 'notDetermined';
      final raw = value?['token'] as String?;
      token = raw == null || raw.isEmpty ? null : raw;
      final failure = value?['registrationError'] as String?;
      error = failure == null || failure.isEmpty ? null : failure;
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
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
