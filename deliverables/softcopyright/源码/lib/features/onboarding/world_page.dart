import 'package:flutter/material.dart';

import 'onboarding_scaffold.dart';

/// Second introduction screen, Figma 271:1590. The conversation is sample copy.
class WorldPage extends StatelessWidget {
  const WorldPage({
    super.key,
    required this.onNext,
    this.busy = false,
    this.error,
  });
  final VoidCallback onNext;
  final bool busy;
  final String? error;
  static const assetNames = [
    'world_ghost',
    'world_dots',
    'world_scene',
    'world_characters',
    'world_indicator',
    'world_badge_icon',
    'next_icon',
  ];

  static Widget _image(String name, double width, double height) => Image.asset(
    'assets/${name == 'world_scene' || name == 'world_characters' ? 'design' : 'onboarding'}/$name.png',
    width: width,
    height: height,
    fit: BoxFit.fill,
    excludeFromSemantics: true,
  );

  Widget _visual(BuildContext context, double width) {
    final cardWidth = width - 48;
    final sceneHeight = cardWidth * 173 / 327;
    final characterWidth = width * 140 / 375;
    final characterHeight = characterWidth * 155.72 / 140;
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 16.25;
    // Preserve the reference overlap normally; large text moves the characters
    // below the transcript so expanded lines remain readable.
    final characterSpace = largeText
        ? characterHeight + 16
        : width * 55.72 / 375;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, characterSpace),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(28, 34, 45, 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF916CFF)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _image('world_scene', cardWidth, sceneHeight),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      sceneHeight - 23.648,
                      12,
                      16.648,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: largeText ? null : 156,
                          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(31),
                            gradient: const LinearGradient(
                              colors: [
                                Color.fromRGBO(172, 219, 255, 0.34),
                                Color.fromRGBO(10, 15, 40, 0),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: Center(
                                  child: _image('world_badge_icon', 10, 9),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Expanded(
                                child: Text(
                                  '欢迎Viitor进入创作广场',
                                  style: TextStyle(
                                    fontFamily: 'PingFang SC',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                    height: 17 / 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _ConversationLine('10:30', '乖乖，今天有没有想我呀？💕'),
                        const SizedBox(height: 10),
                        const _ConversationLine('10:35', '有！超级超级想！'),
                        const SizedBox(height: 10),
                        const _ConversationLine('11:55', '嘿嘿，那奖励你一个摸摸头～'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: _image('world_characters', characterWidth, characterHeight),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    pageIndex: 1,
    nextLabel: '进入这个世界',
    onNext: onNext,
    busy: busy,
    error: error,
    footerOverlap: MediaQuery.textScalerOf(context).scale(16) <= 20
        ? (MediaQuery.sizeOf(context).height >= 780 ? 20 : 8)
        : 0,
    spaceWeights: (top: 75, middle: 9, bottom: 16),
    background: [
      Positioned(
        left: 29,
        top: 0,
        width: 346,
        height: 445,
        child: Image.asset(
          'assets/design/world_background.png',
          fit: BoxFit.fill,
        ),
      ),
    ],
    header: const OnboardingHeader(
      title: '探索世界，',
      subtitle: '不止于眼前。',
      description: '不止陪你聊天，更陪你探索世界。\n去发现未知，认识有趣的人，\n把世界各处的新鲜与精彩，分享给你。',
      left: 24,
      right: 32,
      titleGap: 9,
      descriptionGap: 18,
      descriptionSize: 14,
      descriptionLineHeight: 27,
    ),
    visualBuilder: (width) => _visual(context, width),
  );
}

class _ConversationLine extends StatelessWidget {
  const _ConversationLine(this.time, this.message);
  final String time, message;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.23),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 14 / 11,
            color: Color(0x81FFFFFF),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 18 / 13,
            color: Color(0xDEFFFFFF),
          ),
        ),
      ),
    ],
  );
}
