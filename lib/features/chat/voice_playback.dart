import 'package:audioplayers/audioplayers.dart';

import 'chat_message.dart';

abstract interface class VoicePlayback {
  Future<void> play(VoiceClip clip);
  Future<void> stop();
  Future<void> dispose();
  Stream<void> get completed;
}

class DeviceVoicePlayback implements VoicePlayback {
  final _player = AudioPlayer();
  @override
  Future<void> play(VoiceClip clip) => _player.play(
    clip.ephemeral ? UrlSource(clip.path) : DeviceFileSource(clip.path),
  );
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
  @override
  Stream<void> get completed => _player.onPlayerComplete;
}
