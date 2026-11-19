import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../chat/chat_artwork.dart';
import 'home_chat_hint.dart';

class HomeExploreBanner extends StatefulWidget {
  const HomeExploreBanner({
    super.key,
    required this.onExplore,
    required this.onDrag,
  });

  static const double height = 49;
  final VoidCallback onExplore;
  final ValueChanged<double> onDrag;

  @override
  State<HomeExploreBanner> createState() => _HomeExploreBannerState();
}

class _HomeExploreBannerState extends State<HomeExploreBanner> {
  static const _idleDelay = Duration(seconds: 3);
  Timer? _collapseTimer;
  int? _pointer;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    if (_collapsed || _pointer != null) return;
    _collapseTimer = Timer(_idleDelay, () => setState(() => _collapsed = true));
  }

  void _press(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _collapseTimer?.cancel();
    HapticFeedback.selectionClick();
  }

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _scheduleCollapse();
  }

  void _activate() {
    if (_collapsed) {
      setState(() => _collapsed = false);
      _scheduleCollapse();
    } else {
      widget.onExplore();
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '逛一逛',
    hint: _collapsed ? '展开入口，可上下拖动' : '进入广场，可上下拖动',
    onTap: _activate,
    child: ExcludeSemantics(
      child: Listener(
        onPointerDown: _press,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: _activate,
          onVerticalDragUpdate: (details) => widget.onDrag(details.delta.dy),
          child: ExploreBannerSize(
            child: _collapsed
                ? const ExploreMagnifier()
                : ClipRect(
                    child: SizedBox(
                      width: 130,
                      height: HomeExploreBanner.height,
                      child: Stack(
                        children: [
                          Positioned(
                            left: -107,
                            top: (HomeExploreBanner.height - 40) / 2,
                            child: SvgPicture.asset(
                              'assets/home/explore.svg',
                              width: 237,
                              height: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

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
