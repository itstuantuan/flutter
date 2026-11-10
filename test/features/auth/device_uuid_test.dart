import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bots/features/auth/device_uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const android = MethodChannel('android_id');
  const ios = MethodChannel('dev.fluttercommunity.plus/device_info');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(android, null);
    messenger.setMockMethodCallHandler(ios, null);
  });

  test('Android读取原生ANDROID_ID', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(android, (call) async {
      expect(call.method, 'getId');
      return 'android-device-id';
    });
    expect(await readDeviceUuid('android'), 'android-device-id');
  });

  test('iOS读取原生identifierForVendor', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(ios, (call) async {
      expect(call.method, 'getDeviceInfo');
      return {
        'identifierForVendor': 'ios-vendor-id',
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '18',
        'model': 'iPhone',
        'modelName': 'iPhone',
        'localizedModel': 'iPhone',
        'freeDiskSize': 0,
        'totalDiskSize': 0,
        'physicalRamSize': 0,
        'availableRamSize': 0,
        'isPhysicalDevice': true,
        'isiOSAppOnMac': false,
        'isiOSAppOnVision': false,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'test',
          'release': '1',
          'version': '1',
          'machine': 'iPhone',
        },
      };
    });
    expect(await readDeviceUuid('ios'), 'ios-vendor-id');
  });

  test('空标识和平台不匹配报错，Web不读取设备', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(android, (_) async => null);
    await expectLater(readDeviceUuid('android'), throwsStateError);
    await expectLater(readDeviceUuid('ios'), throwsStateError);
    expect(await readDeviceUuid('web'), null);
  });
}
