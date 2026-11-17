import 'dart:async';

import 'package:flutter/material.dart';

import 'plaza_scenarios.dart';

/// A single story per visit; rebuilds and foregrounding do not redraw it.
class PlazaDialogue extends StatefulWidget {
  const PlazaDialogue({super.key, required this.scenario});
  final PlazaScenario scenario;
  @override
  State<PlazaDialogue> createState() => _PlazaDialogueState();
}

class _PlazaDialogueState extends State<PlazaDialogue>
    with WidgetsBindingObserver {
  late final _lines = widget.scenario.lines;
  final _scroll = ScrollController();
  Timer? _timer;
  int _visible = 1;
  int _elapsed = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_foreground || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _elapsed += 200;
      final delay = (1800 + _lines[_visible - 1].text.runes.length * 90).clamp(
        2600,
        6500,
      );
      if (_elapsed < delay) return;
      _elapsed = 0;
      if (_visible >= _lines.length) {
        _timer?.cancel();
        return;
      }
      final follow = !_scroll.hasClients || _scroll.offset < 40;
      setState(() => _visible++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients || !follow) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(0);
        } else {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.white, Colors.white],
      stops: [0, .07, 1],
    ).createShader(rect),
    child: SingleChildScrollView(
      key: const ValueKey('plaza-content'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(31),
              gradient: const LinearGradient(
                colors: [Color(0x824675FF), Color(0x00FF3ED8)],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/onboarding/world_badge_icon.png',
                  width: 10,
                  height: 9,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    '欢迎Viitor进入创作广场',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 12,
                      height: 17 / 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _visible; i++)
            TweenAnimationBuilder<double>(
              key: ValueKey('plaza-line-$i'),
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              builder: (context, value, child) => ClipRect(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  heightFactor: value,
                  child: Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (_lines[i].speaker.isNotEmpty)
                        TextSpan(
                          text: '${_lines[i].speaker}: ',
                          style: const TextStyle(
                            color: Color(0xFF6ADAFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(text: _lines[i].text),
                    ],
                  ),
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontSize: 14,
                    height: 20 / 14,
                    color: Color(0xDEFFFFFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
