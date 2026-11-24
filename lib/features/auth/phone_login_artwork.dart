import '../../core/localization/app_localizations.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget loginSvg(String name, {required double width, required double height}) =>
    SvgPicture.asset(
      'assets/login/$name.svg',
      width: width,
      height: height,
      excludeFromSemantics: true,
    );

/// Original Figma artwork placed in its 375px design viewport.
class PhoneLoginArtwork extends StatelessWidget {
  const PhoneLoginArtwork({
    super.key,
    required this.codeStep,
    this.google = false,
  });
  final bool codeStep;
  final bool google;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final width = math.min(bounds.maxWidth, 600.0);
          final height = codeStep ? 227.0 : 309.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: height * width / 375,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: 375,
                  height: height,
                  child: ClipRect(child: codeStep ? _characters() : _cards()),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _characters() => Opacity(
    opacity: .72 * .46,
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00FFFFFF),
          Color(0xC5FFFFFF),
          Color(0x4DFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, .519868, .833481, 1],
      ).createShader(rect),
      child: Stack(
        children: [
          for (final item in [
            (x: -80.09, y: 31.94, flipped: true),
            (x: 174.56, y: 29.0, flipped: false),
          ])
            Positioned(
              left: item.x,
              top: item.y,
              width: 293.709,
              height: 361.336,
              child: Center(
                child: Transform.rotate(
                  angle: (item.flipped ? 22.04 : -22.04) * math.pi / 180,
                  child: Transform.flip(
                    flipX: item.flipped,
                    child: Image.asset(
                      'assets/login/otp_character.png',
                      width: 190.236,
                      height: 312.811,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _cards() => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x00FFFFFF),
        Color(0x38FFFFFF),
        Color(0x66FFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: [0, .188459, .512898, 1],
    ).createShader(Rect.fromLTWH(0, -1, rect.width, 309)),
    child: Stack(
      children: [
        for (final card in google ? _googleCards : _loginCards)
          Positioned(
            left: card.x,
            top: card.y,
            width: card.w,
            height: card.h,
            child: Center(
              child: Transform.rotate(
                angle:
                    (google && card.avatar == 'wang' ? -6.97 : -6.63) *
                    math.pi /
                    180,
                child: Container(
                  width: card.textWidth + 76,
                  height: 71,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A34),
                    border: Border.all(color: const Color(0xFF46474E)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 39,
                        height: 39,
                        child: OverflowBox(
                          minWidth: 41,
                          maxWidth: 41,
                          minHeight: 41,
                          maxHeight: 41,
                          child: card.avatar == 'other'
                              ? loginSvg('avatar_other', width: 41, height: 41)
                              : Image.asset(
                                  'assets/login/avatar_${card.avatar}.png',
                                  width: 41,
                                  height: 41,
                                ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              card.name,
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                inherit: false,
                                fontFamily: 'PingFang SC',
                                fontSize: 14,
                                height: 16 / 14,
                                letterSpacing: google ? 0 : 1,
                                color: Color(0xFF9B9CA1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              card.topic,
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                inherit: false,
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                height: 17 / 14,
                                letterSpacing: google ? 0 : 1,
                                color: card.color,
                              ),
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
      ],
    ),
  );
}

const _loginCards = [
  (
    x: 195.41,
    y: 173.68,
    w: 233.909,
    h: 98.712,
    textWidth: 151.0,
    avatar: 'fish',
    name: '小鱼在逛',
    topic: '猫咪到底在想些什么',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: -204.9,
    y: 218.58,
    w: 247.815,
    h: 100.328,
    textWidth: 165.0,
    avatar: 'other',
    name: '可乐在逛',
    topic: '如果明天不用上班会怎样',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: 285.92,
    y: 79.44,
    w: 218.015,
    h: 96.866,
    textWidth: 135.0,
    avatar: 'wang',
    name: '旺仔在逛',
    topic: '和陌生人聊起了童年',
    color: Color(0xFFE4D4F5),
  ),
  (
    x: 46.41,
    y: 201.26,
    w: 145.503,
    h: 88.44,
    textWidth: 62.0,
    avatar: 'qixi',
    name: '七喜在逛',
    topic: '深夜吃瓜',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: 108.88,
    y: 103.19,
    w: 173.316,
    h: 91.672,
    textWidth: 90.0,
    avatar: 'abu',
    name: '阿布在逛',
    topic: '路人观察日记',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: -128.29,
    y: 125.72,
    w: 233.909,
    h: 98.712,
    textWidth: 151.0,
    avatar: 'other',
    name: '糯米在逛',
    topic: '今天的打工人又崩溃了',
    color: Color(0xFFDAF3F7),
  ),
  (
    x: 206.35,
    y: 1.1,
    w: 218.015,
    h: 96.866,
    textWidth: 135.0,
    avatar: 'duck',
    name: '卷饼鸭鸭在逛',
    topic: '在和宠物店老板对话',
    color: Color(0xFFDAF3F7),
  ),
  (
    x: 29.54,
    y: 26.83,
    w: 173.316,
    h: 91.672,
    textWidth: 90.0,
    avatar: 'jiang',
    name: '酱酱在逛',
    topic: '如何上班摸鱼',
    color: Color(0xFFE4D4F5),
  ),
  (
    x: -215.58,
    y: 49.37,
    w: 241.855,
    h: 99.636,
    textWidth: 159.0,
    avatar: 'other',
    name: '康康在逛',
    topic: '咖啡店老板约周五social',
    color: Color(0xFFF8F6D7),
  ),
];

const _googleCards = [
  (
    x: 152.41,
    y: 163.0,
    w: 353.19,
    h: 112.573,
    textWidth: 271.084,
    avatar: 'fish',
    name: 'Xiaoyu is Exploring',
    topic: 'What Are Cats Really Thinking?',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: -306.0,
    y: 226.65,
    w: 247.815,
    h: 100.328,
    textWidth: 165.0,
    avatar: 'other',
    name: '可乐在逛',
    topic: '如果明天不用上班会怎样',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: 227.14,
    y: 58.93,
    w: 416.719,
    h: 122.329,
    textWidth: 334.897,
    avatar: 'wang',
    name: 'Wangzai is Exploring',
    topic: 'Talking Childhood Memories with Strangers',
    color: Color(0xFFE4D4F5),
  ),
  (
    x: -57.0,
    y: 207.0,
    w: 207.049,
    h: 95.592,
    textWidth: 123.96,
    avatar: 'qixi',
    name: 'Qixi is Exploring',
    topic: 'Late-Night Gossip',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: -38.12,
    y: 110.56,
    w: 264.751,
    h: 102.296,
    textWidth: 182.05,
    avatar: 'abu',
    name: 'Abu is Exploring',
    topic: 'A Stranger-Watching Diary',
    color: Color(0xFFF8F6D7),
  ),
  (
    x: -275.29,
    y: 141.72,
    w: 233.909,
    h: 98.712,
    textWidth: 151.0,
    avatar: 'other',
    name: '糯米在逛',
    topic: '今天的打工人又崩溃了',
    color: Color(0xFFDAF3F7),
  ),
  (
    x: 289.0,
    y: -12.0,
    w: 218.015,
    h: 96.866,
    textWidth: 135.0,
    avatar: 'duck',
    name: '卷饼鸭鸭在逛',
    topic: 'Hoat Work',
    color: Color(0xFFDAF3F7),
  ),
  (
    x: 29.54,
    y: 16.8,
    w: 259.662,
    h: 101.705,
    textWidth: 176.926,
    avatar: 'jiang',
    name: 'Nana is Exploring',
    topic: 'How to Slack Off at Work',
    color: Color(0xFFE4D4F5),
  ),
  (
    x: -215.58,
    y: 49.37,
    w: 241.855,
    h: 99.636,
    textWidth: 159.0,
    avatar: 'other',
    name: '康康在逛',
    topic: '咖啡店老板约周五social',
    color: Color(0xFFF8F6D7),
  ),
];
