class VoiceClip {
  const VoiceClip({
    required this.path,
    required this.duration,
    this.ephemeral = false,
  });
  final String path;
  final Duration duration;
  final bool ephemeral;

  Map<String, dynamic> toJson() => {
    'path': path,
    'durationMs': duration.inMilliseconds,
    'ephemeral': ephemeral,
  };

  factory VoiceClip.fromJson(Map<String, dynamic> value) => VoiceClip(
    path: value['path'] as String,
    duration: Duration(milliseconds: value['durationMs'] as int),
    ephemeral: value['ephemeral'] == true,
  );
}

class ChatMessage {
  const ChatMessage(this.text, {this.isUser = false, this.voice});
  final String text;
  final bool isUser;
  final VoiceClip? voice;

  factory ChatMessage.fromStored(String value) {
    final separator = value.indexOf('：');
    return ChatMessage(
      separator < 0 ? value : value.substring(separator + 1),
      isUser: value.startsWith('你：'),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> value) => ChatMessage(
    value['text'] as String? ?? '',
    isUser: value['isUser'] == true,
    voice: value['voice'] is Map
        ? VoiceClip.fromJson(Map<String, dynamic>.from(value['voice'] as Map))
        : null,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    if (voice != null) 'voice': voice!.toJson(),
  };
}
