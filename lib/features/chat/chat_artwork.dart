import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget chatSvg(
  String name, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) => SvgPicture.asset(
  'assets/chat/$name.svg',
  width: width,
  height: height,
  fit: fit,
  excludeFromSemantics: true,
);

class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Opacity(
          opacity: 0.5,
          child: Image.asset(
            'assets/chat/background.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 139,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xA819171C), Color(0x0019171C)],
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 294,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x5E000000),
                  Color(0xE0000000),
                ],
                stops: [0, 0.48171, 1],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ChatGlass extends StatelessWidget {
  const ChatGlass({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(31),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2.35, sigmaY: 2.35),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x30FFFFFF),
          borderRadius: BorderRadius.circular(31),
          border: Border.all(color: const Color(0x33FFFFFF), width: 0.456),
        ),
        child: child,
      ),
    ),
  );
}

class ChatGreeting extends StatelessWidget {
  const ChatGreeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
            child: chatSvg('greeting_fill', fit: BoxFit.fill),
          ),
        ),
      ),
      Positioned(
        left: 7.5,
        right: 7.5,
        top: 9.5,
        bottom: 9.5,
        child: chatSvg('greeting_border', fit: BoxFit.fill),
      ),
      Positioned(
        right: 4,
        top: 4,
        child: chatSvg('greeting_corner', width: 6, height: 6),
      ),
      for (final position in [
        (left: 5.2445, top: true),
        (left: 5.2445, top: false),
      ])
        Positioned(
          left: position.left,
          top: position.top ? 3.2445 : null,
          bottom: position.top ? null : 5.2445,
          child: chatSvg('greeting_star', width: 5.511, height: 5.511),
        ),
      Positioned(
        right: 4.2445,
        bottom: 5.2445,
        child: chatSvg('greeting_star', width: 5.511, height: 5.511),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 79),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          child: Text(
            '嗨!我是$name.很高兴见到你!\n在一起探索之前,我想先多了解你一点.',
            style: const TextStyle(
              inherit: false,
              textBaseline: TextBaseline.alphabetic,
              fontFamily: 'PingFang SC',
              fontSize: 14,
              height: 22 / 14,
              color: Color(0xFFD6D6D6),
            ),
          ),
        ),
      ),
    ],
  );
}

class ChatExploreBanner extends StatefulWidget {
  const ChatExploreBanner({
    super.key,
    required this.onPressed,
    this.collapseAfter = const Duration(seconds: 3),
    this.onDragUpdate,
    this.onCollapsedChanged,
    this.initiallyCollapsed = false,
  });
  final VoidCallback? onPressed;
  final Duration collapseAfter;
  final bool initiallyCollapsed;
  final ValueChanged<Offset>? onDragUpdate;
  final ValueChanged<bool>? onCollapsedChanged;
  @override
  State<ChatExploreBanner> createState() => _ChatExploreBannerState();
}

class _ChatExploreBannerState extends State<ChatExploreBanner> {
  Timer? _timer;
  late bool _collapsed = widget.initiallyCollapsed;
  Offset _lastDrag = Offset.zero;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_collapsed) return;
    _timer = Timer(widget.collapseAfter, () {
      if (!mounted) return;
      setState(() => _collapsed = true);
      widget.onCollapsedChanged?.call(true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '先去探索世界',
    hint: widget.onDragUpdate != null ? '长按可上下拖动位置' : null,
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: widget.onPressed,
        onLongPressStart: widget.onDragUpdate != null
            ? (_) {
                _timer?.cancel();
                _lastDrag = Offset.zero;
              }
            : null,
        onLongPressMoveUpdate: widget.onDragUpdate != null
            ? (details) {
                widget.onDragUpdate!(
                  Offset(0, details.offsetFromOrigin.dy - _lastDrag.dy),
                );
                _lastDrag = details.offsetFromOrigin;
              }
            : null,
        onLongPressEnd: widget.onDragUpdate != null ? (_) => _schedule() : null,
        onLongPressCancel: widget.onDragUpdate != null ? _schedule : null,
        behavior: HitTestBehavior.opaque,
        child: ExploreBannerSize(
          child: _collapsed
              ? const ExploreMagnifier()
              : SizedBox(
                  width: 188,
                  height: 48,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 4,
                        left: 0,
                        width: 188,
                        height: 40,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              Positioned(
                                left: -49,
                                top: 0,
                                child: chatSvg(
                                  'banner_background',
                                  width: 237,
                                  height: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 29,
                        top: 33.97,
                        child: chatSvg(
                          'banner_star_5',
                          width: 5,
                          height: 4.994,
                        ),
                      ),
                      Positioned(
                        left: 56,
                        top: 13.99,
                        child: chatSvg(
                          'banner_star_3',
                          width: 3,
                          height: 2.996,
                        ),
                      ),
                      Positioned(
                        left: 48,
                        top: 7,
                        child: chatSvg(
                          'banner_star_10',
                          width: 10,
                          height: 8.989,
                        ),
                      ),
                      Positioned(
                        left: 18,
                        top: 8.93,
                        width: 49,
                        height: 29.905,
                        child: Center(
                          child: Transform.rotate(
                            angle: -14.98 * math.pi / 180,
                            child: chatSvg(
                              'banner_ring',
                              width: 46.7007,
                              height: 19.7298,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 33,
                        top: 14,
                        child: Text(
                          '先去探索世界',
                          style: TextStyle(
                            inherit: false,
                            textBaseline: TextBaseline.alphabetic,
                            fontFamily: 'PingFang SC',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 139,
                        top: 19.98,
                        child: chatSvg(
                          'banner_chevrons',
                          width: 11,
                          height: 10.987,
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

class ExploreBannerSize extends StatelessWidget {
  const ExploreBannerSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          child: child,
        );
}

class ExploreMagnifier extends StatelessWidget {
  const ExploreMagnifier({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 49,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: 6,
          width: 68,
          height: 43,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21.5),
            child: Image.asset(
              'assets/chat/explore_compact_background.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
        Positioned(
          left: 45,
          top: 22,
          child: chatSvg('banner_chevrons', width: 11, height: 10.987),
        ),
        Positioned(
          left: 0,
          top: -1,
          width: 41.088,
          height: 42.053,
          child: Transform.rotate(
            angle: 3.78 * math.pi / 180,
            child: Center(
              child: SizedBox(
                width: 38.561,
                height: 39.596,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        left: -38.561 * .2013,
                        top: -39.596 * .1634,
                        width: 38.561 * 1.3423,
                        height: 39.596 * 1.3072,
                        child: Image.asset(
                          'assets/chat/explore_magnifier.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.highlightText,
    this.textKey,
  });
  final String text;
  final bool isUser;
  final String? highlightText;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = math.min(269.0, constraints.maxWidth);
      final style = TextStyle(
        inherit: false,
        textBaseline: TextBaseline.alphabetic,
        fontFamily: 'PingFang SC',
        fontSize: 15,
        height: 18 / 15,
        color: isUser ? const Color(0xFF333333) : Colors.white,
      );
      final measurement = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, maxWidth - 24));
      final width = (measurement.width.ceilToDouble() + 24).clamp(
        0.0,
        maxWidth,
      );
      measurement.dispose();
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: SizedBox(
          width: width.toDouble(),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFFD6CBFF)
                        : const Color(0x80000000),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 12 : 14),
                      topRight: Radius.circular(isUser ? 12 : 14),
                      bottomLeft: Radius.circular(isUser ? 12 : 2),
                      bottomRight: Radius.circular(isUser ? 2 : 14),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: isUser ? 38 : 0),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isUser ? 10 : 12,
                  ),
                  child: _text(style),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _text(TextStyle style) {
    final highlight = highlightText;
    final index = highlight == null || highlight.isEmpty
        ? -1
        : text.indexOf(highlight);
    if (index < 0) return Text(text, key: textKey, style: style);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: highlight,
            style: const TextStyle(
              backgroundColor: Color(0xFFFFDF84),
              color: Color(0xFF38224F),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(index + highlight!.length)),
        ],
      ),
      key: textKey,
      style: style,
    );
  }
}

/// Original transparent Figma layers, node 305:4497, at their native geometry.
class ChatSendIcon extends StatelessWidget {
  const ChatSendIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 50,
    height: 50,
    child: Stack(
      children: [
        chatSvg('send_background', width: 50, height: 50),
        Positioned(
          left: 8.34,
          top: 5.56,
          width: 37.176,
          height: 36.523,
          child: Center(
            child: Transform.rotate(
              angle: 64.97 * math.pi / 180,
              child: SizedBox(
                width: 27.047,
                height: 28.399,
                child: Stack(
                  children: [
                    Positioned(
                      left: 27.047 * 0.0963,
                      top: 28.399 * 0.0914,
                      child: chatSvg(
                        'send_arrow',
                        width: 22.1866,
                        height: 23.0497,
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
