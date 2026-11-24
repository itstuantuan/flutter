import 'chat_message.dart';

/// Presentation-only grouping. Server turns remain separate for replies,
/// unread receipts and navigation; one exploration task shares one carousel.
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

List<ChatTranscriptEntry> chatTranscriptEntries(List<ChatMessage> messages) {
  final selected = <ChatMessage, List<Map<String, dynamic>>>{};
  final seen = <(String, Object)>{};
  for (final message in messages.reversed) {
    if (!message.hasStructuredDiscoveries) continue;
    final cards = <Map<String, dynamic>>[];
    for (final card in message.cards) {
      final id = card['materialId'];
      final task = message.referenceTaskId;
      if (task != null && id != null && !seen.add((task, id))) continue;
      cards.add(card);
    }
    selected[message] = cards;
  }

  final entries = <ChatTranscriptEntry>[];
  final batches = <String, ChatTranscriptEntry>{};
  for (final source in messages) {
    var message = source;
    if (source.hasStructuredDiscoveries) {
      final cards = selected[source]!;
      if (cards.isEmpty) continue;
      message = ChatMessage(
        source.text,
        isInterfaceText: source.isInterfaceText,
        turnId: source.turnId,
        referenceTaskId: source.referenceTaskId,
        cards: cards,
        createdAt: source.createdAt,
        animateReply: source.animateReply,
      );
    }
    final task = message.hasStructuredDiscoveries
        ? message.referenceTaskId
        : null;
    final batch = batches[task];
    if (batch != null) {
      batch.messages.add(message);
      continue;
    }
    final entry = ChatTranscriptEntry([message]);
    entries.add(entry);
    if (task != null) batches[task] = entry;
  }
  return entries;
}
