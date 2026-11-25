import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Implicit transitions keep each button independent while a save is pending.
class DiscoveryFeedbackButton extends StatefulWidget {
  const DiscoveryFeedbackButton({
    super.key,
    required this.selected,
    this.positive = true,
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final bool selected, positive;
  final VoidCallback? onPressed;
  final Widget icon, label;

  @override
  State<DiscoveryFeedbackButton> createState() =>
      _DiscoveryFeedbackButtonState();
}

class _DiscoveryFeedbackButtonState extends State<DiscoveryFeedbackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  final _link = LayerLink();
  OverlayEntry? _particles;

  @override
  void initState() {
    super.initState();
    _burst =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _removeParticles();
        });
  }

  void _removeParticles() {
    _particles?.remove();
    _particles?.dispose();
    _particles = null;
  }

  void _tap() {
    final action = widget.onPressed;
    if (action == null) return;
    if (!widget.positive) {
      if (!widget.selected && !MediaQuery.disableAnimationsOf(context)) {
        _burst.duration = const Duration(milliseconds: 420);
        _burst.forward(from: 0);
      }
      action();
      return;
    }
    if (!widget.selected && !MediaQuery.disableAnimationsOf(context)) {
      _removeParticles();
      final painter = _ConfettiPainter(_burst, math.Random().nextInt(1 << 30));
      _particles = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.center,
                    followerAnchor: Alignment.center,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(320, 320),
                        painter: painter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      Overlay.of(context).insert(_particles!);
      _burst.forward(from: 0);
    }
    action();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _burst.stop();
      _removeParticles();
    }
  }

  @override
  void dispose() {
    _removeParticles();
    _burst.dispose();
    super.dispose();
  }

  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        selected: widget.selected,
        child: Listener(
          onPointerDown: (_) {
            if (widget.onPressed != null) _press(true);
          },
          onPointerUp: (_) => _press(false),
          onPointerCancel: (_) => _press(false),
          child: AnimatedScale(
            scale: reduced || !_pressed ? 1 : .96,
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(91),
                border: Border.all(color: const Color(0x5CD4C9EB)),
                gradient: LinearGradient(
                  colors: widget.selected
                      ? const [Color(0xFF5832EF), Color(0xFF8B42DE)]
                      : const [Color(0x005832EF), Color(0x008B42DE)],
                ),
              ),
              child: TextButton(
                onPressed: widget.onPressed == null ? null : _tap,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  overlayColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  animationDuration: Duration.zero,
                  minimumSize: const Size(0, 39),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: reduced || !widget.selected || !widget.positive
                          ? 1
                          : 1.12,
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      child: AnimatedBuilder(
                        animation: _burst,
                        child: widget.icon,
                        builder: (context, child) {
                          final t = _burst.value;
                          final active =
                              !reduced &&
                              !widget.positive &&
                              _burst.isAnimating;
                          return Transform.translate(
                            key: const ValueKey('feedback-icon-motion'),
                            offset: active
                                ? Offset(
                                    math.sin(t * math.pi * 4) * 3 * (1 - t),
                                    0,
                                  )
                                : Offset.zero,
                            child: child,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    widget.label,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short ballistic burst: drag slows the spread while gravity brings it down.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.animation, int seed)
    : particles = _makeParticles(seed),
      super(repaint: animation);
  final Animation<double> animation;
  final List<({double vx, double vy, double spin, double width, Color color})>
  particles;

  static List<({double vx, double vy, double spin, double width, Color color})>
  _makeParticles(int seed) {
    final random = math.Random(seed);
    const colors = [
      Color(0xFFB48AFF),
      Color(0xFFFF8FD8),
      Color(0xFF7DE6FF),
      Color(0xFFFFD878),
      Color(0xFFFFFFFF),
    ];
    return List.generate(24, (i) {
      final angle = -math.pi + random.nextDouble() * math.pi;
      final speed = 90 + random.nextDouble() * 110;
      return (
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 35,
        spin: (random.nextDouble() - .5) * 14,
        width: 3 + random.nextDouble() * 3,
        color: colors[i % colors.length],
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final spread = (1 - math.exp(-2 * t)) / 2;
    final opacity = ((1 - t) / .4).clamp(0.0, 1.0);
    for (final p in particles) {
      canvas.save();
      canvas.translate(
        size.width / 2 + p.vx * spread,
        size.height / 2 + p.vy * spread + 95 * t * t,
      );
      canvas.rotate(p.spin * t);
      canvas.scale(1, .35 + .65 * math.cos(t * 12 + p.spin).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.width * 1.6,
          ),
          const Radius.circular(.8),
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate != this;
}
