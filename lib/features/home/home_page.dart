import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shared/design_scene.dart';
import 'home_chat_hint.dart';

enum DiscoveryStyle { blue, purple, glass }

class HomeDiscovery {
  const HomeDiscovery({
    required this.description,
    required this.title,
    this.style = DiscoveryStyle.blue,
  });
  final String description, title;
  final DiscoveryStyle style;
}

/// 11.12 Figma homepage, 271:1403; the glass variant is 288:2019.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onMenu,
    required this.onExplore,
    required this.onChat,
    required this.onVoice,
    required this.onDiscovery,
    this.onFriends,
    this.discoveries = designDiscoveries,
    this.initialPage = 0,
  });
  final VoidCallback onMenu, onExplore, onChat, onVoice;
  final VoidCallback? onFriends;
  final ValueChanged<int> onDiscovery;
  final List<HomeDiscovery> discoveries;
  final int initialPage;
  static const designDiscoveries = [
    HomeDiscovery(description: '广场上出现了新的创作挑战:', title: '“用AI创作一段属于秋天的故”'),
    HomeDiscovery(
      description: '广场上出现了新的创作挑战:',
      title: '“用AI创作一段属于秋天的故”',
      style: DiscoveryStyle.purple,
    ),
    HomeDiscovery(
      description: '广场上出现了新的创作挑战:',
      title: '“用AI创作一段属于秋天的故”',
      style: DiscoveryStyle.glass,
    ),
  ];
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pages = PageController(
    initialPage: widget.initialPage,
    viewportFraction: 327 / 375,
  );
  late int _selected = widget.initialPage;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.discoveries.length &&
        widget.discoveries.isNotEmpty) {
      _selected = widget.discoveries.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF18191E),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF18191E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safe = MediaQuery.paddingOf(context);
          final contentWidth = math.min(
            constraints.maxWidth - safe.horizontal,
            600.0,
          );
          final sceneScale = math.max(
            contentWidth / 375,
            constraints.maxHeight / 812,
          );
          final cardWidth = contentWidth * 327 / 375 - 12;
          final cardHeight = widget.discoveries.fold<double>(
            185,
            (height, item) => math.max(
              height,
              _DiscoveryCard.heightFor(context, item, cardWidth),
            ),
          );
          final glass =
              widget.discoveries.isNotEmpty &&
              widget
                      .discoveries[_selected.clamp(
                        0,
                        widget.discoveries.length - 1,
                      )]
                      .style ==
                  DiscoveryStyle.glass;
          final cardTop = safe.top + (glass ? 62 : 70);
          final indicatorTop = safe.top + 70 + cardHeight + 14;
          final sceneOffset = math.max(
            0.0,
            indicatorTop + 30 - 360 * sceneScale,
          );
          final footerBottom = math.max(24.0, safe.bottom) + 6;
          // Decorative artwork covers the viewport; its scaled height must
          // not create scroll extent on shorter phones. Only actual content
          // (for example accessibility-sized cards) may require scrolling.
          final canvasHeight = math.max(
            constraints.maxHeight,
            indicatorTop + 26 + 16 + 48 + footerBottom,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  key: const ValueKey('home-content'),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      height: canvasHeight,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Positioned(
                              left: (contentWidth - 375 * sceneScale) / 2,
                              top: sceneOffset,
                              width: 375 * sceneScale,
                              height: 812 * sceneScale,
                              child: const DesignScene(
                                asset: 'assets/design/home_raw.png',
                                sourceRect: Rect.fromLTWH(
                                  -25.04,
                                  -88,
                                  413.08,
                                  926.55,
                                ),
                                semanticLabel: 'ViiTor 在星空露台向你挥手',
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 237 * sceneScale,
                              child: const IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0x66000000),
                                        Color(0x85000000),
                                      ],
                                      stops: [0, 0.88984, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: cardTop,
                              height: cardHeight,
                              child: PageView.builder(
                                key: const ValueKey('home-discoveries'),
                                controller: _pages,
                                itemCount: widget.discoveries.length,
                                onPageChanged: (value) =>
                                    setState(() => _selected = value),
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 5,
                                    right: 7,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _pages,
                                    builder: (context, child) {
                                      final page =
                                          _pages.hasClients &&
                                              _pages
                                                  .position
                                                  .hasContentDimensions
                                          ? (_pages.page ??
                                                _selected.toDouble())
                                          : _selected.toDouble();
                                      final distance = (page - index)
                                          .abs()
                                          .clamp(0.0, 1.0);
                                      return Transform.translate(
                                        offset: Offset(0, 18 * distance),
                                        child: Transform.scale(
                                          scale: 1 - 0.152 * distance,
                                          alignment: Alignment.topLeft,
                                          child: _DiscoveryCard(
                                            discovery:
                                                widget.discoveries[index],
                                            outlined: distance > 0.5,
                                            onPressed: () =>
                                                widget.onDiscovery(index),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: indicatorTop - 16,
                              height: 42,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (
                                    var i = 0;
                                    i < widget.discoveries.length;
                                    i++
                                  )
                                    Semantics(
                                      label: '发现第 ${i + 1} 页',
                                      selected: i == _selected,
                                      button: true,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _pages.animateToPage(
                                          i,
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 250,
                                                ),
                                          curve: Curves.easeOut,
                                        ),
                                        child: SizedBox(
                                          width: 20,
                                          height: 42,
                                          child: Center(
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: i == _selected
                                                    ? const Color(0xFFE5DFFF)
                                                    : null,
                                                border: i == _selected
                                                    ? null
                                                    : Border.all(
                                                        color: const Color(
                                                          0xFF9990C3,
                                                        ),
                                                        width: 0.7,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
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
              ),
              Positioned(
                left: safe.left + 7,
                top: safe.top + 3,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: '菜单',
                    onPressed: widget.onMenu,
                    padding: EdgeInsets.zero,
                    icon: _svg('menu', 22.9583, 20.5417),
                  ),
                ),
              ),
              Positioned(
                left: safe.left + 16,
                right: safe.right + 16,
                bottom: footerBottom,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Transform.translate(
                      offset: const Offset(-16, 0),
                      child: Tooltip(
                        message: '逛一逛',
                        child: Semantics(
                          button: true,
                          label: '逛一逛',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onExplore,
                            child: SizedBox(
                              width: 130,
                              height: 45,
                              child: Center(
                                child: ClipRect(
                                  child: SizedBox(
                                    width: 130,
                                    height: 40,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: -107,
                                          top: 0,
                                          child: SvgPicture.asset(
                                            'assets/home/explore.svg',
                                            width: 237,
                                            height: 40,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _GlassPill(
                      width: 116,
                      height: 45,
                      opacity: 0.15,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ToolbarAction(
                            label: '聊天',
                            asset: 'chat',
                            onPressed: widget.onChat,
                          ),
                          _ToolbarAction(
                            label: '语音',
                            asset: 'microphone',
                            onPressed: widget.onVoice,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: safe.right + 16,
                bottom: footerBottom - 39,
                width: 183,
                height: 180,
                child: const HomeChatHint(),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Widget _svg(String name, double width, double height) => SvgPicture.asset(
  'assets/home/$name.svg',
  width: width,
  height: height,
  excludeFromSemantics: true,
);

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.discovery,
    required this.onPressed,
    this.outlined = false,
  });
  final bool outlined;
  final HomeDiscovery discovery;
  final VoidCallback onPressed;
  static const descriptionStyle = TextStyle(
    fontFamily: 'PingFang SC',
    fontSize: 16,
    height: 31 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: Colors.white,
  );
  static const titleStyle = TextStyle(
    fontFamily: 'PingFang SC',
    fontSize: 18,
    height: 31 / 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: Colors.white,
  );
  static double heightFor(
    BuildContext context,
    HomeDiscovery item,
    double width,
  ) {
    double measure(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width - 78));
      final h = p.height;
      p.dispose();
      return h;
    }

    final scaler = MediaQuery.textScalerOf(context);
    return math.max(
      185,
      81 +
          math.max(0, scaler.scale(16) - 16) * 17 / 16 +
          math.max(42, scaler.scale(14) * 1.25 + 16) +
          measure(item.description, descriptionStyle) +
          measure(item.title, titleStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = discovery.style == DiscoveryStyle.blue;
    final purple = discovery.style == DiscoveryStyle.purple;
    final glass = discovery.style == DiscoveryStyle.glass;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (outlined)
          SvgPicture.asset(
            'assets/home/secondary_background.svg',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          )
        else if (blue)
          SvgPicture.asset(
            'assets/design/card_blue.svg',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          )
        else if (glass)
          Image.asset(
            'assets/design/card_glass.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: purple ? const Color(0xFF1B1336) : null,
              gradient: purple
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF304960), Color(0xFF2A222D)],
                    ),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
          ),
        if (purple && !outlined)
          Positioned(
            top: 0,
            right: 0,
            width: 315,
            height: 185,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 2.75, sigmaY: 2.75),
                child: SvgPicture.asset(
                  'assets/design/card_mask.svg',
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        if (purple && !outlined) const Positioned.fill(child: _CardStars()),
        if (blue && !outlined)
          const Positioned(
            left: 12,
            right: 12,
            bottom: 26,
            height: 20,
            child: _CardDiamonds(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 18),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: glass
                    ? Semantics(
                        label: '今日发现',
                        child: Image.asset(
                          'assets/design/card_glass_heading.png',
                          width: 146,
                          height: 28,
                          excludeFromSemantics: true,
                        ),
                      )
                    : const _DiscoveryHeading(),
              ),
              const SizedBox(height: 10.716),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      discovery.description,
                      textAlign: TextAlign.center,
                      style: glass
                          ? descriptionStyle.copyWith(
                              color: const Color(0xFF090909),
                            )
                          : descriptionStyle,
                    ),
                    Text(
                      discovery.title,
                      textAlign: TextAlign.center,
                      style: glass
                          ? titleStyle.copyWith(color: const Color(0xFF090909))
                          : titleStyle,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 165,
                height: math.max(
                  42,
                  MediaQuery.textScalerOf(context).scale(14) * 1.25 + 16,
                ),
                child: TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    overlayColor: Colors.transparent,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111111),
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    '去看看',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardStars extends StatelessWidget {
  const _CardStars();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => IgnorePointer(
      child: Stack(
        children: [
          for (final p in [
            (x: 11.0, y: 154.0, w: 15.0, h: 15.0, name: 'star_glow7'),
            (x: 291.0, y: 113.0, w: 15.0, h: 11.0, name: 'star_glow_wide'),
            (x: 17.0, y: 106.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 34.0, y: 60.0, w: 6.0, h: 6.0, name: 'star_glow2'),
            (x: 119.0, y: 99.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 187.0, y: 14.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 52.0, y: 131.0, w: 10.0, h: 10.0, name: 'star_glow2_large'),
            (x: 286.0, y: 161.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 264.0, y: 142.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 204.0, y: 108.0, w: 11.0, h: 11.0, name: 'star_glow3'),
            (x: 170.0, y: 69.0, w: 6.0, h: 6.0, name: 'star_glow2'),
            (x: 113.0, y: 30.0, w: 6.0, h: 6.0, name: 'star_glow2'),
          ])
            Positioned(
              left: p.x * c.maxWidth / 315,
              top: p.y * c.maxHeight / 185,
              width: p.w,
              height: p.h,
              child: Image.asset(
                'assets/design/${p.name}.png',
                excludeFromSemantics: true,
              ),
            ),
        ],
      ),
    ),
  );
}

class _DiscoveryHeading extends StatelessWidget {
  const _DiscoveryHeading();
  @override
  Widget build(BuildContext context) => SizedBox(
    width:
        146 + math.max(0, MediaQuery.textScalerOf(context).scale(16) - 16) * 4,
    height:
        28 +
        math.max(0, MediaQuery.textScalerOf(context).scale(16) - 16) * 17 / 16,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 2,
          child: Transform.rotate(
            angle: -math.pi / 12,
            child: _svg('orbit', 40, 17),
          ),
        ),
        Positioned(left: 9, top: 23, child: _svg('star_5', 5, 5)),
        Positioned(left: 32, top: 6, child: _svg('star_3', 3, 3)),
        Positioned(left: 26, top: 0, child: _svg('star_8', 8, 8)),
        const Positioned(
          left: 12,
          top: 8,
          child: Text(
            '今日发现',
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: 16,
              height: 17 / 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardDiamonds extends StatelessWidget {
  const _CardDiamonds();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var group = 0; group < 2; group++)
        SizedBox(
          width: 22,
          height: 20,
          child: Stack(
            children: [
              for (final item in [
                (x: 0.0, y: 5.0, size: 5.762, alpha: 0.3),
                (x: 10.09, y: 0.0, size: 7.683, alpha: 0.5),
                (x: 7.13, y: 12.67, size: 3.841, alpha: 0.2),
              ])
                Positioned(
                  left: item.x,
                  top: item.y,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: item.alpha),
                      child: SizedBox.square(dimension: item.size),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.width,
    required this.height,
    required this.opacity,
    required this.child,
  });
  final double width, height, opacity;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: math.max(48, height),
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(188),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.35, sigmaY: 2.35),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(188),
              border: Border.all(color: Colors.white.withValues(alpha: 0.37)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.label,
    required this.asset,
    required this.onPressed,
  });
  final String label, asset;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 45,
    height: 45,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 45, minHeight: 45),
      icon: _svg(asset, 24, 24),
    ),
  );
}
