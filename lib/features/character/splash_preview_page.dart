import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashPreviewPage extends StatefulWidget {
  const SplashPreviewPage({super.key});
  @override
  State<SplashPreviewPage> createState() => _SplashPreviewPageState();
}

class _SplashPreviewPageState extends State<SplashPreviewPage>
    with TickerProviderStateMixin {
  late final AnimationController entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final AnimationController ribbons = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      entrance.value = 1;
      idle.stop();
      ribbons.stop();
    } else {
      if (entrance.value == 0) entrance.forward();
      if (!idle.isAnimating) idle.repeat();
      if (!ribbons.isAnimating) ribbons.repeat();
    }
  }

  @override
  void dispose() {
    entrance.dispose();
    idle.dispose();
    ribbons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF26134F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            constraints.maxWidth,
            constraints.maxHeight * 390 / 844,
          );
          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 390,
                    height: 844,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([entrance, idle, ribbons]),
                      builder: (context, _) {
                        final enter = Curves.easeOutCubic.transform(
                          entrance.value,
                        );
                        final phase = idle.value * math.pi * 2;
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            const Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(-0.5, -0.7),
                                    radius: 1.3,
                                    colors: [
                                      Color(0xFF6033AD),
                                      Color(0xFF43208C),
                                      Color(0xFF411C87),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -35,
                              top: 45,
                              width: 480,
                              height: 720,
                              child: Opacity(
                                opacity: 0.085,
                                child: Image.asset(
                                  'assets/characters/viitor_idle.png',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: CustomPaint(painter: _DotsPainter()),
                            ),
                            Positioned(
                              top: 155 + (1 - enter) * 14,
                              left: 30,
                              right: 30,
                              child: Opacity(
                                opacity: enter,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Divider(
                                            color: Color(0x556DD6FF),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                colors: [
                                                  Color(0xFF65C8FF),
                                                  Color(0xFFE96BF5),
                                                ],
                                              ).createShader(bounds),
                                          child: const Text(
                                            'Pals',
                                            style: TextStyle(
                                              fontSize: 39,
                                              fontWeight: FontWeight.w900,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.white,
                                              letterSpacing: -1.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        const Expanded(
                                          child: Divider(
                                            color: Color(0x55ED8AF8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 9),
                                    const Text(
                                      'Your AI friend and digital twin.',
                                      style: TextStyle(
                                        color: Color(0xFFCF7CDE),
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: -60 - (1 - enter) * 400,
                              top: 345,
                              width: 540,
                              height: 50,
                              child: Transform.rotate(
                                angle: 0.16,
                                child: _Ribbon(
                                  text: 'Pals     Your AI friend and digital twin.',
                                  progress: ribbons.value,
                                  fontSize: 23,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 55,
                              top: 275 + (1 - enter) * 70,
                              width: 290,
                              height: 485,
                              child: Opacity(
                                opacity: enter,
                                child: Transform.translate(
                                  offset: Offset(
                                    math.sin(phase) * 1.5,
                                    -2 * (1 - math.cos(phase)),
                                  ),
                                  child: Transform.rotate(
                                    angle: math.sin(phase) * 0.009,
                                    alignment: Alignment.bottomCenter,
                                    child: Transform.scale(
                                      scaleY:
                                          1 + 0.008 * (1 - math.cos(phase)) / 2,
                                      alignment: Alignment.bottomCenter,
                                      child: RepaintBoundary(
                                        child: Image.asset(
                                          'assets/characters/viitor_splash.png',
                                          fit: BoxFit.contain,
                                          semanticLabel: '紫发 Pals 侧身微笑，手持小人偶',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -90 + (1 - enter) * 500,
                              top: 688,
                              width: 590,
                              height: 59,
                              child: Transform.rotate(
                                angle: -0.52,
                                child: _Ribbon(
                                  text: 'Welcome to Pals!',
                                  progress: -ribbons.value,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 277,
                              top: 627,
                              child: Transform.rotate(
                                angle: -0.3,
                                child: const Icon(
                                  Icons.forum_rounded,
                                  color: Colors.white,
                                  size: 51,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 270,
                              top: 151,
                              child: Opacity(
                                opacity:
                                    0.55 + 0.45 * (1 + math.sin(phase)) / 2,
                                child: const Text(
                                  '✦',
                                  style: TextStyle(
                                    color: Color(0xFFF875EF),
                                    fontSize: 23,
                                  ),
                                ),
                              ),
                            ),
                            for (final star in [
                              const Offset(89, 540),
                              const Offset(313, 442),
                              const Offset(293, 580),
                            ])
                              Positioned(
                                left: star.dx,
                                top: star.dy,
                                child: Opacity(
                                  opacity:
                                      (0.3 +
                                          0.7 *
                                              (1 + math.sin(phase + star.dx)) /
                                              2) *
                                      enter,
                                  child: const Text(
                                    '✧',
                                    style: TextStyle(
                                      color: Color(0xFFFFDFFF),
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: SizedBox(
        width: 38,
        height: 38,
        child: FloatingActionButton.small(
          heroTag: 'splash-replay',
          tooltip: '重播入场动画',
          backgroundColor: const Color(0x55412087),
          elevation: 0,
          onPressed: () {
            if (!MediaQuery.disableAnimationsOf(context)) {
              entrance.forward(from: 0);
            }
          },
          child: const Icon(Icons.replay, color: Colors.white70, size: 19),
        ),
      ),
    ),
  );
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.text,
    required this.fontSize,
    required this.progress,
  });
  final String text;
  final double fontSize;
  final double progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB743F4), Color(0xFF8B68FF)],
        ),
      ),
      child: CustomPaint(painter: _RibbonTextPainter(text, fontSize, progress)),
    ),
  );
}

class _RibbonTextPainter extends CustomPainter {
  _RibbonTextPainter(this.text, this.fontSize, this.progress);
  final String text;
  final double fontSize;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final label = TextPainter(
      text: TextSpan(
        text: '$text     ',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = label.width;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Repeat exact measured text widths so wrapping at the cycle is seamless.
    final offset = (progress * width) % width;
    for (double x = -offset; x < size.width; x += width) {
      label.paint(canvas, Offset(x, (size.height - label.height) / 2));
    }
    canvas.restore();
    label.dispose();
  }

  @override
  bool shouldRepaint(covariant _RibbonTextPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      text != oldDelegate.text ||
      fontSize != oldDelegate.fontSize;
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (double y = 0; y < size.height; y += 8) {
      for (double x = 0; x < size.width; x += 8) {
        final top = math.max(0.0, 1 - Offset(x - 360, y - 25).distance / 170);
        final bottom = math.max(
          0.0,
          1 - Offset(x - 30, y - 810).distance / 210,
        );
        final mid = math.max(0.0, 1 - Offset(x - 10, y - 510).distance / 95);
        final intensity = math.max(top, math.max(bottom, mid));
        if (intensity > 0) {
          paint.color = Colors.white.withValues(alpha: intensity * 0.13);
          canvas.drawCircle(Offset(x, y), 0.7 + intensity * 2.4, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => false;
}
