import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'onboarding_scaffold.dart';

/// First introduction screen, Figma 271:1557. Progress belongs to the caller.
class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onNext,
    this.busy = false,
    this.error,
  });

  final VoidCallback onNext;
  final bool busy;
  final String? error;

  static const assetNames = [
    'dots',
    'rings',
    'avatar_purple',
    'avatar_boy',
    'avatar_pink',
    'star_blue',
    'star_small',
    'star_pink',
    'indicator',
    'next_icon',
  ];

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final _motionController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 234),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motionController.stop();
      _motionController.value = 0;
    } else if (!_motionController.isAnimating) {
      _motionController.repeat();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Widget _motion(String name, Widget child) {
    if (name != 'rings' && !name.startsWith('avatar_')) return child;
    return AnimatedBuilder(
      animation: _motionController,
      child: child,
      builder: (context, child) {
        final elapsed = _motionController.value * 234;
        final phase = elapsed / 6 * math.pi * 2;
        if (name == 'rings') {
          final breath = (1 - math.cos(phase)) / 2;
          return Opacity(
            opacity: 1 - breath * 0.15,
            child: Transform.scale(scale: 1 + breath * 0.04, child: child),
          );
        }
        if (MediaQuery.disableAnimationsOf(context)) return child!;
        final motion = switch (name) {
          'avatar_boy' => (period: 3.0, phase: 2.1, amplitude: 10.0),
          'avatar_pink' => (period: 2.6, phase: 4.2, amplitude: 8.0),
          _ => (period: 3.6, phase: 0.0, amplitude: 12.0),
        };
        final angle = elapsed / motion.period * math.pi * 2;
        final scale = MediaQuery.sizeOf(context).width.clamp(0, 375) / 375;
        return Transform.translate(
          offset: Offset(
            math.sin(angle + motion.phase) * 4 * scale,
            math.sin(angle + motion.phase) * motion.amplitude * scale,
          ),
          child: Transform.rotate(
            angle: math.sin(angle + motion.phase + math.pi / 3) * math.pi / 60,
            child: child,
          ),
        );
      },
    );
  }

  Widget _image(String name, double width, double height) => _motion(
    name,
    RepaintBoundary(
      child: Image.asset(
        'assets/onboarding/$name.png',
        width: width,
        height: height,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
    ),
  );

  Widget _bubble(double scale) => Transform.rotate(
    angle: -4.89 * math.pi / 180,
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(5),
        bottomRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: ColoredBox(
          color: const Color.fromRGBO(255, 255, 255, 0.19),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 22 * scale,
              vertical: 16 * scale,
            ),
            child: const Text(
              '来啦~欢迎小宝加入',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PingFang SC',
                letterSpacing: 0,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _visual(double width) {
    final scale = width / 375;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 240 * scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final item in [
                (name: 'avatar_purple', x: 19.0, y: 35.0, size: 63.0),
                (name: 'avatar_boy', x: 278.0, y: 147.0, size: 53.0),
                (name: 'avatar_pink', x: 94.0, y: 177.0, size: 40.0),
                (name: 'star_blue', x: 321.0, y: 0.0, size: 16.0),
                (name: 'star_small', x: 53.0, y: 224.0, size: 10.0),
                (name: 'star_pink', x: 37.0, y: 208.0, size: 16.0),
              ])
                Positioned(
                  left: item.x * scale,
                  top: item.y * scale,
                  child: _image(
                    item.name,
                    item.size * scale,
                    item.size * scale,
                  ),
                ),
              if (!largeText)
                Positioned(
                  left: 95.718 * scale,
                  top: 74.584 * scale,
                  width: 180 * scale,
                  child: _bubble(scale),
                ),
            ],
          ),
        ),
        if (largeText)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: _bubble(1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    pageIndex: 0,
    onNext: widget.onNext,
    busy: widget.busy,
    error: widget.error,
    spaceWeights: (top: 8200, middle: 2200, bottom: 8448),
    background: [
      Positioned(
        left: 28.66,
        top: 0,
        width: 346.34,
        height: 272.31,
        child: Image.asset('assets/design/welcome_dots.png', fit: BoxFit.fill),
      ),
      Positioned(left: 0, top: 166, child: _image('rings', 375, 545)),
    ],
    header: const OnboardingHeader(
      title: '遇见懂你的TA,',
      subtitle: '开启专属陪伴',
      description: 'Pals是一个懂你、关心你的AI伙伴,随时和你\n聊天,记住你的喜好与想法,陪伴你一起成长.',
      left: 18,
      right: 38,
      titleGap: 11,
      descriptionGap: 11,
      descriptionSize: 15,
      descriptionLineHeight: 25,
    ),
    visualBuilder: _visual,
  );
}
