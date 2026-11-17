import 'package:flutter/material.dart';

import 'chat_message.dart';
import 'chat_page.dart';

enum ChatPreviewState { welcome, conversation, recording, returning, discovery }

const chatDiscoveryPreview = ChatMessage(
  '',
  turnId: 999,
  cards: [
    {
      'materialId': 'preview-1',
      'title': '听说唱，你更在意押韵还是表达？',
      'summary': '从格莱美说唱类奖项页面寻找作品，比较不同的节奏与叙事。哪句表达让你记住一首歌？不用会唱，也能聊聊自己的感受。',
    },
    {
      'materialId': 'preview-2',
      'title': '一首歌，藏着怎样的故事？',
      'summary': '换一种角度听熟悉的旋律，看看歌词里有没有与你相似的经历。',
    },
    {
      'materialId': 'preview-3',
      'title': '今天想发现什么？',
      'summary': '从音乐、电影和旅行中，找一个想继续聊下去的话题。',
    },
  ],
);

const chatPreviewMessages = [
  ChatMessage(
    'I do not know when I reached out my hand and stroked your face, looking into your bright eyes.',
  ),
  ChatMessage('What now!', isUser: true),
  ChatMessage(
    'I do not know when I reached out my\nI do not know when I reached out my hand and stroked your face, looking into your bright eyes.',
  ),
  ChatMessage('What now!What now!What now!What now!What now!', isUser: true),
];

/// Explicit design-only routes never request microphone permission on opening.
class ChatPreviewPage extends StatelessWidget {
  const ChatPreviewPage({
    super.key,
    this.state = ChatPreviewState.welcome,
    this.animate = true,
  });
  final ChatPreviewState state;
  final bool animate;
  @override
  Widget build(BuildContext context) => ChatPage(
    messages: state == ChatPreviewState.discovery
        ? [
            chatPreviewMessages.first,
            for (final (index, card) in chatDiscoveryPreview.cards.indexed)
              ChatMessage(
                '',
                turnId: 999 + index,
                referenceTaskId: 'preview-task-$index',
                cards: [card],
              ),
            ...chatPreviewMessages.skip(1).take(2),
          ]
        : state == ChatPreviewState.welcome
        ? const []
        : state == ChatPreviewState.conversation
        ? chatPreviewMessages.take(2).toList()
        : chatPreviewMessages,
    initialRecordingPreview:
        state == ChatPreviewState.recording ||
        state == ChatPreviewState.returning,
    returningUser:
        state == ChatPreviewState.returning ||
        state == ChatPreviewState.discovery,
    showWelcome: state != ChatPreviewState.discovery,
    timeLabel: '14:07',
    animate: animate,
    onExit: () => Navigator.maybePop(context),
    onExplore: () => Navigator.maybePop(context),
  );
}
