import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> newVoicePath() async {
  final root = await getApplicationSupportDirectory();
  final directory = await Directory('${root.path}/voice-notes')
      .create(recursive: true);
  return '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
}

Future<bool> voiceFileExists(String path) async {
  final file = File(path);
  return await file.exists() && await file.length() > 44;
}

Future<void> deleteVoiceFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
