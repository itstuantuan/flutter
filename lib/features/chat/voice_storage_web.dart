import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> newVoicePath() async => '';
Future<bool> voiceFileExists(String path) async => path.startsWith('blob:');
Future<void> deleteVoiceFile(String path) async =>
    web.URL.revokeObjectURL(path);

Future<Uint8List> readVoiceBytes(String path) async {
  final response = await web.window.fetch(path.toJS).toDart;
  if (!response.ok) throw StateError('无法读取录音');
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}
