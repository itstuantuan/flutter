import 'dart:math' as math;
import 'dart:ui';

import '../chat/chat_page.dart';
import 'plaza_dialogue.dart';
import 'plaza_scenarios.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Plaza artwork with locally scripted conversations from Figma 340:6678.
class PlazaPage extends StatefulWidget {
  const PlazaPage({super.key, this.onChat, this.onVoice});
  final VoidCallback? onChat, onVoice;
  @override
  State<PlazaPage> createState() => _PlazaPageState();
}

class _PlazaPageState extends State<PlazaPage> {
  static final _picker = PlazaScenarioPicker();
  late final _scenario = _picker.next();

  void _chat(BuildContext context, bool voice) {
    final callback = voice ? widget.onVoice : widget.onChat;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (chatContext) => ChatPage(
          returningUser: true,
          startRecordingOnOpen: voice,
          onExit: () => Navigator.pop(chatContext),
          onExplore: () => Navigator.pop(chatContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF19171C),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF19171C),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safe = MediaQuery.paddingOf(context);
          final width = math.min(constraints.maxWidth - safe.horizontal, 600.0);
          final scale = math.max(width / 375, constraints.maxHeight / 812);
          return Stack(
            children: [
              // The scene covers a fixed viewport. Its crop does not set
              // page height; only the transcript can scroll when necessary.
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: 0,
                          left: (width - 375 * scale) / 2,
                          width: 375 * scale,
                          height: 812 * scale,
                          child: Image.asset(
                            'assets/design/plaza_scene.png',
                            fit: BoxFit.fill,
                            semanticLabel: 'ViiTor 和伙伴们在明亮的创作广场散步',
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 357 * scale,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x0019171C),
                                    Color(0x6619171C),
                                    Color(0x7819171C),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 258 * scale,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x0019171C),
                                    Color(0x8019171C),
                                    Color(0x9619171C),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: math.max(safe.bottom, 34) + 73,
                height: math.min(
                  170 * MediaQuery.textScalerOf(context).scale(14) / 14,
                  math.max(
                    80,
                    constraints.maxHeight -
                        safe.top -
                        math.max(safe.bottom, 34) -
                        173,
                  ),
                ),
                left: (constraints.maxWidth - width) / 2 + 22,
                right: (constraints.maxWidth - width) / 2 + 22,
                child: PlazaDialogue(scenario: _scenario),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: safe.top + 87,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Colors.transparent],
                        stops: [0.25, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: (constraints.maxWidth - width) / 2 + 17,
                bottom: math.max(safe.bottom, 34) + 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(39),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.7, sigmaY: 8.7),
                    child: Container(
                      width: 120,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0x2EFFFFFF),
                        borderRadius: BorderRadius.circular(39),
                        border: Border.all(
                          color: const Color(0x80FFFFFF),
                          width: .5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '广场聊天',
                            onPressed: () => _chat(context, false),
                            icon: SvgPicture.asset(
                              'assets/home/chat.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          IconButton(
                            tooltip: '广场语音',
                            onPressed: () => _chat(context, true),
                            icon: SvgPicture.asset(
                              'assets/home/microphone.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: safe.top + 8,
                left: safe.left + 4,
                right: safe.right + 4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '返回首页',
                      onPressed: () => Navigator.maybePop(context),
                      icon: SvgPicture.asset(
                        'assets/design/plaza_back.svg',
                        width: 24,
                        height: 24,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _scenario.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: 16,
                          height: 22 / 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
