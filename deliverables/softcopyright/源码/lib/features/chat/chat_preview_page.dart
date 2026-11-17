import 'package:flutter/material.dart';

import 'chat_message.dart';
import 'chat_page.dart';

enum ChatPreviewState { welcome, conversation, recording, returning }

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
    messages: state == ChatPreviewState.welcome
        ? const []
        : state == ChatPreviewState.conversation
        ? chatPreviewMessages.take(2).toList()
        : chatPreviewMessages,
    initialRecordingPreview:
        state == ChatPreviewState.recording ||
        state == ChatPreviewState.returning,
    returningUser: state == ChatPreviewState.returning,
    timeLabel: '14:07',
    animate: animate,
    onExit: () => Navigator.maybePop(context),
    onExplore: () => Navigator.maybePop(context),
  );
}
