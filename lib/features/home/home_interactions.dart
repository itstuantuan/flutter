import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_chat_hint.dart';

/// Pointer feedback leaves gesture recognition and accessibility to the button.
class HomePressFeedback extends StatefulWidget {
  const HomePressFeedback({super.key, required this.child});
  final Widget child;
  @override
  State<HomePressFeedback> createState() => _HomePressFeedbackState();
}

class _HomePressFeedbackState extends State<HomePressFeedback> {
  final _pointers = <int>{};
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_pointers.isEmpty) HapticFeedback.selectionClick();
      setState(() => _pointers.add(event.pointer));
    },
    onPointerUp: (event) => setState(() => _pointers.remove(event.pointer)),
    onPointerCancel: (event) => setState(() => _pointers.remove(event.pointer)),
    child: AnimatedScale(
      scale: _pointers.isEmpty ? 1 : .95,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _pointers.isEmpty ? 1 : .82,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    ),
  );
}

class FirstHomeChatHint extends StatefulWidget {
  const FirstHomeChatHint({
    super.key,
    required this.userId,
    this.storage = const FlutterSecureStorage(),
  });
  final String userId;
  final FlutterSecureStorage storage;
  @override
  State<FirstHomeChatHint> createState() => _FirstHomeChatHintState();
}

class _FirstHomeChatHintState extends State<FirstHomeChatHint> {
  static final _seen = <String>{};
  bool _visible = false;
  String get _key => 'home.chat-hint.seen.v1.${widget.userId}';
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final key = _key;
    if (_seen.contains(key)) return;
    String? saved;
    try {
      saved = await widget.storage.read(key: key);
    } catch (_) {}
    if (!mounted || _seen.contains(key) || saved == 'true') return;
    setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_visible) return;
      _seen.add(key);
      try {
        await widget.storage.write(key: key, value: 'true');
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? const HomeChatHint() : const SizedBox.shrink();
}
