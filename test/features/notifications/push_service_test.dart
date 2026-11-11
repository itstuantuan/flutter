import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/features/notifications/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('push-test');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('本地通知使用原生调度，不依赖 APNs token', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    final service = PushService(channel: channel);
    expect(await service.scheduleDemo(), isTrue);
    expect(calls, ['scheduleDemo']);
    expect(service.token, isNull);
    expect(service.busy, isFalse);
    service.dispose();
  });
  test('拒绝不产生 token，授权不等于获取 token', () async {
    var status = 'denied';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return {
            'authorization': status,
            'token': '',
            'registrationError': '',
          };
        });
    final service = PushService(channel: channel);
    await service.request();
    expect(service.allowed, false);
    expect(service.token, isNull);
    status = 'authorized';
    await service.request();
    expect(service.allowed, true);
    expect(service.token, isNull);
    service.dispose();
  });
  test('桥接错误可恢复，不卡住 busy', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'failed');
        });
    final service = PushService(channel: channel);
    await service.request();
    expect(service.busy, false);
    expect(service.error, isNotNull);
    service.dispose();
  });
}
