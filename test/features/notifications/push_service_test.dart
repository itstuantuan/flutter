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
  test(
    'drains cold-start notifications and deduplicates repeated IDs',
    () async {
      final messages = [
        {
          'event': 'exploration_completed',
          'taskId': 'task-1',
          'sessionId': 's',
          'notificationId': 'n1',
        },
        {
          'event': 'exploration_completed',
          'taskId': 'task-1',
          'sessionId': 's',
          'notificationId': 'n1',
        },
        {
          'event': 'exploration_completed',
          'taskId': 'task-2',
          'sessionId': 's',
          'notificationId': 'n2',
        },
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => messages.isEmpty ? null : messages.removeAt(0),
          );
      final service = PushService(channel: channel);
      await service.readNotification();
      expect(service.pendingNotification?['taskId'], 'task-1');
      service.pendingNotification = null;
      expect(service.pendingNotification?['taskId'], 'task-2');
      service.pendingNotification = null;
      expect(service.pendingNotification, isNull);
      service.dispose();
    },
  );
  test(
    'reads production from native signing metadata independent of API host',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {
              'authorization': 'authorized',
              'token': 'token',
              'environment': 'production',
            },
          );
      final service = PushService(channel: channel);
      await service.refresh();
      expect(service.environment, 'production');
      expect(service.error, isNull);
      service.dispose();
    },
  );
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
