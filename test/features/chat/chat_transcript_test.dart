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
  test('keeps older discovery pushes in conversation order', () {
    final messages = [for (var id = 1; id <= 6; id++) discovery(id)];
    List<Object?> ids() =>
        chatTranscriptEntries(messages)
            .expand((entry) => entry.cards)
            .map((card) => card['materialId'])
            .toList();
    expect(ids(), ['m-1', 'm-2', 'm-3', 'm-4', 'm-5', 'm-6']);
    messages.add(discovery(7));
    expect(ids(), ['m-1', 'm-2', 'm-3', 'm-4', 'm-5', 'm-6', 'm-7']);
    expect(chatTranscriptEntries(messages), hasLength(7));
  });
  test(
    'deduplicates repeated materials from the same exploration',
    () {
      final first = discovery(1);
      final duplicate = ChatMessage(
        '',
        turnId: 3,
        referenceTaskId: first.referenceTaskId,
        cards: first.cards,
      );
      final entries = chatTranscriptEntries([first, discovery(2), duplicate]);
      expect(
        entries
            .expand((entry) => entry.cards)
            .map((card) => card['materialId']),
        ['m-2', 'm-1'],
      );
    },
  );
  test('preserves all cards and server order within a result', () {
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
      'm-4',
      'm-5',
    ]);
  });

  test('groups only the same exploration at its first position', () {
    ChatMessage discovery(int id) => ChatMessage(
      '',
      turnId: id,
      referenceTaskId: id <= 3 ? 'first' : id <= 5 ? 'second' : 'third',
      cards: [
        {'materialId': 'material-$id', 'title': '发现$id', 'summary': '摘要$id'},
      ],
    );
    final source = [
      discovery(1),
      discovery(2),
      const ChatMessage('我想聊聊这个', isUser: true),
      discovery(3),
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
    expect(entries.length, 5);
    expect(entries[0].cards.length, 3);
    expect(entries[1].message.isUser, isTrue);
    expect(entries[2].cards.length, 2);
    expect(entries[3].message.text, '旧版完整正文');
    expect(entries[4].cards.length, 1);
    expect(source[0].cards.single.containsKey('_chatTurnId'), isFalse);
  });
}
