import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage discovery(int id) => ChatMessage(
    '',
    turnId: id,
    referenceTaskId: 'task-$id',
    cards: [
      {'materialId': 'm-$id', 'summary': '发现$id'},
    ],
  );
  test('keeps only newest three across history and new pushes', () {
    final messages = [for (var id = 1; id <= 6; id++) discovery(id)];
    List<Object?> ids() =>
        chatTranscriptEntries(messages)
            .expand((entry) => entry.cards)
            .map((card) => card['materialId'])
            .toList();
    expect(ids(), ['m-4', 'm-5', 'm-6']);
    messages.add(discovery(7));
    expect(ids(), ['m-5', 'm-6', 'm-7']);
  });
  test(
    'home selection replaces old cards even when old turns arrive later',
    () {
      final messages = [discovery(1), discovery(2), discovery(3), discovery(4)];
      final entries = chatTranscriptEntries(
        messages,
        visibleCards: [
          {'taskId': 'task-3', 'materialId': 'm-3'},
          {'taskId': 'task-4', 'materialId': 'm-4'},
        ],
      );
      expect(
        entries
            .expand((entry) => entry.cards)
            .map((card) => card['materialId']),
        ['m-3', 'm-4'],
      );
      expect(chatTranscriptEntries(messages, visibleCards: []), isEmpty);
    },
  );
  test('preserves server order and caps oversized single results', () {
    final entries = chatTranscriptEntries([
      ChatMessage(
        '',
        cards: [
          for (var id = 1; id <= 5; id++)
            {'materialId': 'm-$id', 'summary': '发现$id'},
        ],
      ),
    ]);
    expect(entries.single.cards.map((card) => card['materialId']), [
      'm-1',
      'm-2',
      'm-3',
    ]);
  });

  test('groups adjacent discoveries without crossing chat or legacy text', () {
    ChatMessage discovery(int id) => ChatMessage(
      '',
      turnId: id,
      cards: [
        {'materialId': 'material-$id', 'title': '发现$id', 'summary': '摘要$id'},
      ],
    );
    final source = [
      discovery(1),
      discovery(2),
      discovery(3),
      const ChatMessage('我想聊聊这个', isUser: true),
      discovery(4),
      discovery(5),
      const ChatMessage(
        '旧版完整正文',
        turnId: 6,
        cards: [
          {'materialId': 'legacy', 'title': '旧版发现'},
        ],
      ),
      discovery(7),
    ];
    final entries = chatTranscriptEntries(source);
    expect(entries.length, 4);
    expect(entries[0].message.isUser, isTrue);
    expect(entries[1].cards.length, 2);
    expect(entries[2].message.text, '旧版完整正文');
    expect(entries[3].cards.length, 1);
    expect(source[0].cards.single.containsKey('_chatTurnId'), isFalse);
  });
}
