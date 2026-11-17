import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Code-drawn glow and hint with a gentle continuous animation.
/// This layer never moves or intercepts the actual chat/voice controls.
class HomeChatHint extends StatefulWidget {
  const HomeChatHint({super.key});
  @override
  State<HomeChatHint> createState() => _HomeChatHintState();
}

class _HomeChatHintState extends State<HomeChatHint>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final phase = _motion.value * math.pi * 2;
            final breath = (1 - math.cos(phase)) / 2;
            return SizedBox(
              width: 183,
              height: 180,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 40,
                    top: 57.5,
                    child: Transform.scale(
                      key: const ValueKey('home-chat-ring'),
                      scale: 1 + .12 * breath,
                      child: Opacity(
                        opacity: .9 + .1 * breath,
                        child: CustomPaint(
                          size: const Size(122, 122),
                          painter: _RingPainter(progress: _motion.value),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 51,
                    top: 68.5,
                    child: Transform.scale(
                      scale: 1 + .06 * breath,
                      child: CustomPaint(
                        size: const Size(100, 100),
                        painter: _RingPainter(
                          progress: _motion.value,
                          inner: true,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Transform.translate(
                      key: const ValueKey('home-chat-hint-motion'),
                      offset: Offset(0, -5 * math.sin(phase)),
                      child: SizedBox(
                        width: 150,
                        height: 80,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 13,
                              top: 3,
                              child: const CustomPaint(
                                size: Size(127, 44),
                                painter: _BubblePainter(),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Opacity(
                                opacity: .55 + .45 * breath,
                                child: const CustomPaint(
                                  size: Size(12, 12),
                                  painter: _StarPainter(),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 96.5,
                              top: 44,
                              child: CustomPaint(
                                size: const Size(9, 31),
                                painter: _ThreadPainter(glow: breath),
                              ),
                            ),
                            const Positioned(
                              left: 13,
                              top: 12,
                              width: 127,
                              child: Text(
                                '快跟我聊聊吧',
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontFamily: 'PingFang SC',
                                  fontSize: 14,
                                  height: 20 / 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: .14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, this.inner = false});
  final double progress;
  final bool inner;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = inner ? 29.0 : 39.0;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final breath = (1 - math.cos(progress * math.pi * 2)) / 2;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = inner ? 5 : 9
      ..color = const Color(0xFFD59AFF).withValues(alpha: .55 + .25 * breath)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, inner ? 4 : 7);
    canvas.drawCircle(center, radius, glow);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inner ? 1.8 : 2.4
        ..shader = SweepGradient(
          transform: GradientRotation(progress * math.pi * 2),
          colors: const [
            Color(0x99CA9AFF),
            Color(0xFFFFF5FF),
            Color(0xFFE0B8FF),
            Color(0x99CA9AFF),
          ],
          stops: const [0, .35, .6, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.inner != inner;
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(19.5, .5)
      ..lineTo(107.5, .5)
      ..arcToPoint(const Offset(107.5, 38.5), radius: const Radius.circular(19))
      ..lineTo(96.5, 38.5)
      ..quadraticBezierTo(95.5, 38.5, 95, 39.5)
      ..lineTo(93, 42)
      ..quadraticBezierTo(91.5, 44, 90, 42)
      ..lineTo(88, 39.5)
      ..quadraticBezierTo(87, 38.5, 85, 38.5)
      ..lineTo(19.5, 38.5)
      ..arcToPoint(const Offset(19.5, .5), radius: const Radius.circular(19))
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x666E358B), Color(0x337E3BB0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFD1AAFE),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(4.5, 0),
      const Offset(4.5, 26.5),
      Paint()
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00BA7AFF), Color(0xFFEFDAFF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      const Offset(4.5, 26.5),
      3.5 + glow,
      Paint()
        ..color = const Color(0x99D694F9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      const Offset(4.5, 26.5),
      2,
      Paint()..color = const Color(0xFFF6E4FF),
    );
  }

  @override
  bool shouldRepaint(_ThreadPainter oldDelegate) => oldDelegate.glow != glow;
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (final (center, radius) in [
      (const Offset(5, 5), 5.0),
      (const Offset(10, 10), 2.0),
    ]) {
      final path = Path()..moveTo(center.dx, center.dy - radius);
      for (var i = 0; i < 4; i++) {
        final angle = -math.pi / 2 + i * math.pi / 2;
        final next = angle + math.pi / 2;
        path.quadraticBezierTo(
          center.dx + math.cos(angle + math.pi / 4) * radius * .3,
          center.dy + math.sin(angle + math.pi / 4) * radius * .3,
          center.dx + math.cos(next) * radius,
          center.dy + math.sin(next) * radius,
        );
      }
      canvas.drawPath(path..close(), Paint()..color = const Color(0xFFD1AAFE));
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => false;
}
