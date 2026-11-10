import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Android 使用 ANDROID_ID，iOS 使用 identifierForVendor；Web 不采集设备标识。
/// 系统标识可能因系统重置或应用重装等操作改变，不保证永久不变。
Future<String?> readDeviceUuid(String platform) async {
  if (platform == 'web') return null;
  if (kIsWeb) throw StateError('当前运行平台与账号平台配置不一致');
  final String? value;
  if (platform == 'android' &&
      defaultTargetPlatform == TargetPlatform.android) {
    value = await const AndroidId().getId();
  } else if (platform == 'ios' && defaultTargetPlatform == TargetPlatform.iOS) {
    value = (await DeviceInfoPlugin().iosInfo).identifierForVendor;
  } else {
    throw StateError('当前运行平台与账号平台配置不一致');
  }
  final uuid = value?.trim();
  if (uuid == null || uuid.isEmpty) {
    throw StateError('无法获取设备标识，请稍后重试');
  }
  return uuid;
}
