import 'package:web/web.dart' as web;

Future<String> newVoicePath() async => '';
Future<bool> voiceFileExists(String path) async => path.startsWith('blob:');
Future<void> deleteVoiceFile(String path) async =>
    web.URL.revokeObjectURL(path);
