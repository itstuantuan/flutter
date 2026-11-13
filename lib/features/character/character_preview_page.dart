import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A replaceable static asset animated without an additional runtime.
class IdleCharacter extends StatefulWidget {
  const IdleCharacter({super.key, this.playing = true, this.amplitude = 1});
  final bool playing;
  final double amplitude;

  @override
  State<IdleCharacter> createState() => _IdleCharacterState();
}

class _IdleCharacterState extends State<IdleCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant IdleCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayback();
  }

  void _syncPlayback() {
    if (widget.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      child: Image.asset(
        'assets/characters/viitor_idle.png',
        fit: BoxFit.contain,
        semanticLabel: '紫色长发的 ViiTor，抬手打招呼，手持小人偶',
      ),
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final amount = MediaQuery.disableAnimationsOf(context)
            ? 0.0
            : widget.amplitude;
        final breath = (1 - math.cos(phase)) / 2;
        return Transform.translate(
          offset: Offset(0, -3 * breath * amount),
          child: Transform.rotate(
            angle: math.sin(phase) * 0.008 * amount,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleX: 1 + 0.004 * breath * amount,
              scaleY: 1 + 0.012 * breath * amount,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    ),
  );
}

class CharacterPreviewPage extends StatefulWidget {
  const CharacterPreviewPage({super.key});

  @override
  State<CharacterPreviewPage> createState() => _CharacterPreviewPageState();
}

class _CharacterPreviewPageState extends State<CharacterPreviewPage> {
  bool playing = true;
  double amplitude = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF171136),
    appBar: AppBar(
      title: const Text('角色待机预览'),
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF171136),
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.9,
          colors: [Color(0xFF6551A8), Color(0xFF171136)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    'ViiTor · 陪在你身边',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 12,
                        child: Container(
                          width: 180,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x665F3EB5),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                          child: IdleCharacter(
                            playing: playing,
                            amplitude: amplitude,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30244D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              playing ? '轻轻呼吸，慢慢摇摆' : '已暂停',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: playing ? '暂停动画' : '播放动画',
                            onPressed: () => setState(() => playing = !playing),
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '动作幅度',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Expanded(
                            child: Slider(
                              value: amplitude,
                              min: 0,
                              max: 2,
                              divisions: 20,
                              label: '${amplitude.toStringAsFixed(1)}×',
                              onChanged: (value) =>
                                  setState(() => amplitude = value),
                            ),
                          ),
                          Text(
                            '${amplitude.toStringAsFixed(1)}×',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const Text(
                        '静态角色图演示 · 后续可替换正式动画素材',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
