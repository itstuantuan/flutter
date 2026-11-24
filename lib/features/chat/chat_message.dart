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
  const ChatMessage(
    this.text, {
    this.isUser = false,
    this.isInterfaceText = false,
    this.voice,
    this.turnId,
    this.referenceTaskId,
    this.cards = const [],
    this.createdAt,
    this.animateReply = false,
    this.isThinking = false,
    this.clientMessageId,
  });
  final String text;
  final bool isUser;

  /// Only app-generated status copy is localized; conversation content is verbatim.
  final bool isInterfaceText;
  final VoiceClip? voice;
  // Server identity is retained for navigation; a discovery stays one turn.
  final int? turnId;
  final String? referenceTaskId;
  final List<Map<String, dynamic>> cards;
  // Older responses may contain only material IDs/titles and aggregate text.
  bool get hasStructuredDiscoveries =>
      !isUser &&
      cards.any(
        (card) =>
            (card['content'] as String? ?? '').trim().isNotEmpty ||
            (card['summary'] as String? ?? '').trim().isNotEmpty,
      );
  final DateTime? createdAt;
  final bool animateReply;
  final bool isThinking;
  final String? clientMessageId;

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
    isInterfaceText: value['isInterfaceText'] == true,
    createdAt: value['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(value['createdAt'] as int)
        : null,
    voice: value['voice'] is Map
        ? VoiceClip.fromJson(Map<String, dynamic>.from(value['voice'] as Map))
        : null,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    if (isInterfaceText) 'isInterfaceText': true,
    if (createdAt != null) 'createdAt': createdAt!.millisecondsSinceEpoch,
    if (voice != null) 'voice': voice!.toJson(),
  };
}
