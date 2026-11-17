import '../exploration/discovery_policy.dart';
import 'chat_message.dart';

/// Presentation-only grouping. Server turns remain separate for replies,
/// unread receipts and navigation; adjacent discoveries share one carousel.
class ChatTranscriptEntry {
  ChatTranscriptEntry(this.messages);

  final List<ChatMessage> messages;
  ChatMessage get message => messages.first;
  bool containsTurn(int? id) =>
      id != null && messages.any((m) => m.turnId == id);

  List<Map<String, dynamic>> get cards => [
    for (final source in messages)
      for (final card in source.cards)
        {
          ...card,
          '_chatTurnId': source.turnId,
          '_chatTaskId': source.referenceTaskId,
        },
  ];
}

List<ChatTranscriptEntry> chatTranscriptEntries(
  List<ChatMessage> messages, {
  List<Map<String, dynamic>>? visibleCards,
}) {
  // Home supplies the authoritative selection. Before it loads, use the newest
  // chat turns, preserving the server's card order within each turn.
  final selected = <ChatMessage, List<Map<String, dynamic>>>{};
  var remaining = maxDiscoveryCards;
  final seen = <String>{};
  for (final message in messages.reversed) {
    if (!message.hasStructuredDiscoveries) continue;
    final cards = <Map<String, dynamic>>[];
    for (final card in message.cards) {
      if (remaining == 0) break;
      if (visibleCards != null &&
          !visibleCards
              .take(maxDiscoveryCards)
              .any(
                (visible) =>
                    visible['materialId'] == card['materialId'] &&
                    visible['taskId'] == message.referenceTaskId,
              )) {
        continue;
      }
      final id = card['materialId'];
      if (id != null && !seen.add('${message.referenceTaskId}:$id')) continue;
      cards.add(card);
      remaining--;
    }
    selected[message] = cards;
  }

  final entries = <ChatTranscriptEntry>[];
  for (final source in messages) {
    var message = source;
    if (source.hasStructuredDiscoveries) {
      final cards = selected[source]!;
      if (cards.isEmpty) continue;
      message = ChatMessage(
        source.text,
        turnId: source.turnId,
        referenceTaskId: source.referenceTaskId,
        cards: cards,
        createdAt: source.createdAt,
        animateReply: source.animateReply,
      );
    }
    if (message.hasStructuredDiscoveries &&
        entries.isNotEmpty &&
        entries.last.message.hasStructuredDiscoveries) {
      entries.last.messages.add(message);
    } else {
      entries.add(ChatTranscriptEntry([message]));
    }
  }
  return entries;
}
