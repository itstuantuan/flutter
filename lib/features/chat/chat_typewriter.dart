import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_artwork.dart';

/// Reveals accumulated server snapshots without restarting on each chunk.
class ChatTypewriter extends StatefulWidget {
  const ChatTypewriter({
    super.key,
    required this.text,
    required this.animate,
    this.textKey,
    this.highlightText,
    this.bubbleKey,
  });
  final String text;
  final bool animate;
  final Key? textKey;
  final String? highlightText;
  final Key? bubbleKey;

  @override
  State<ChatTypewriter> createState() => _ChatTypewriterState();
}

class _ChatTypewriterState extends State<ChatTypewriter> {
  Timer? _timer;
  late List<String> _characters;
  int _visible = 0;

  @override
  void initState() {
    super.initState();
    _characters = widget.text.characters.toList();
    _visible = widget.animate ? 0 : _characters.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ChatTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _characters = widget.text.characters.toList();
    // Corrections/replacements are authoritative, never concatenate snapshots.
    if (!widget.text.startsWith(oldWidget.text)) {
      _visible = _characters.length;
    }
    _sync();
  }

  void _sync() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _visible = _characters.length;
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_visible >= _characters.length || _timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 24), (_) {
      if (!mounted) return;
      setState(() {
        final remaining = _characters.length - _visible;
        _visible += math.min(remaining, math.max(1, (remaining / 20).ceil()));
      });
      if (_visible >= _characters.length) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: ExcludeSemantics(
      child: ChatBubble(
        text: _characters.take(_visible).join(),
        isUser: false,
        textKey: widget.textKey,
        bubbleKey: widget.bubbleKey,
        highlightText: widget.highlightText,
      ),
    ),
  );
}
