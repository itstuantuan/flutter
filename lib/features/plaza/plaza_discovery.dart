import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlazaDiscovery {
  const PlazaDiscovery({
    required this.title,
    required this.body,
    required this.category,
    this.image = 'assets/design/discovery_illustration.png',
  });

  final String title, body, category, image;

  // Local preview content, until exploration results are supplied by the API.
  static const samples = [
    PlazaDiscovery(
      title: '听说唱，你更在意押韵还是表达？',
      body: '从格莱美说唱类奖项页面寻找作品，比较不同的节奏与叙事。哪句表达让你记住一首歌？不用会唱，也能聊聊自己的感受。',
      category: '游戏·烹饪经营',
    ),
    PlazaDiscovery(
      title: '猫咪到底在想些什么？',
      body: '从耳朵、尾巴和叫声，观察猫咪表达情绪的小细节。你家的猫咪有哪些让你好奇的习惯？一起分享那些可爱的瞬间。',
      category: '宠物·猫咪',
    ),
    PlazaDiscovery(
      title: '用 AI 创作一段属于秋天的故事',
      body: '从一片落叶、一杯热饮或一场偶遇开始，写下故事的第一句。让想象继续生长，看看我们能一起创造怎样的秋天。',
      category: '创作·故事',
    ),
  ];
}

Future<PlazaDiscovery?> showPlazaDiscoveries(
  BuildContext context, {
  List<PlazaDiscovery> discoveries = PlazaDiscovery.samples,
  int initialPage = 0,
}) {
  assert(discoveries.isNotEmpty);
  return showDialog<PlazaDiscovery>(
    context: context,
    barrierColor: const Color(0xB3000000),
    barrierLabel: '关闭发现',
    builder: (_) => PlazaDiscoveryDialog(
      discoveries: discoveries,
      initialPage: initialPage,
    ),
  );
}

/// Figma 355:10554. Text and controls remain native; ornaments are local assets.
class PlazaDiscoveryDialog extends StatefulWidget {
  const PlazaDiscoveryDialog({
    super.key,
    required this.discoveries,
    this.initialPage = 0,
  }) : assert(discoveries.length > 0);

  final List<PlazaDiscovery> discoveries;
  final int initialPage;

  @override
  State<PlazaDiscoveryDialog> createState() => _PlazaDiscoveryDialogState();
}

class _PlazaDiscoveryDialogState extends State<PlazaDiscoveryDialog> {
  late int _selected = widget.initialPage.clamp(
    0,
    widget.discoveries.length - 1,
  );
  late final _pages = PageController(initialPage: _selected);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(vertical: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(375.0, constraints.maxWidth);
        final textScale = MediaQuery.textScalerOf(context).scale(21) / 21;
        final height = math.min(
          constraints.maxHeight,
          509.0 + math.max(0, textScale - 1) * 150,
        );
        return SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('plaza-discovery-pages'),
                  controller: _pages,
                  itemCount: widget.discoveries.length,
                  onPageChanged: (value) => setState(() => _selected = value),
                  itemBuilder: (context, index) => SingleChildScrollView(
                    child: _DiscoveryCard(
                      discovery: widget.discoveries[index],
                      onOpen: () =>
                          Navigator.pop(context, widget.discoveries[index]),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (
                      var index = 0;
                      index < widget.discoveries.length;
                      index++
                    )
                      Semantics(
                        button: true,
                        selected: index == _selected,
                        label:
                            '第 ${index + 1} 条发现，共 ${widget.discoveries.length} 条',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _pages.animateToPage(
                            index,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 16,
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _selected
                                      ? Colors.white
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: .7,
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
        );
      },
    ),
  );
}

Widget _decoration(String name) => SvgPicture.asset(
  'assets/design/discovery_$name.svg',
  fit: BoxFit.fill,
  excludeFromSemantics: true,
);

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.discovery, required this.onOpen});
  final PlazaDiscovery discovery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth / 375;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 17.862 * scale,
            right: 57 * scale,
            top: 25.72,
            bottom: 0,
            child: _decoration('back_outline'),
          ),
          Positioned(
            left: 27.48 * scale,
            right: 29.122 * scale,
            top: 15.986,
            bottom: 8,
            child: _decoration('back_paper'),
          ),
          Positioned(
            left: 128.395 * scale,
            top: 1.015,
            width: 146.248 * scale,
            height: 26.874,
            child: Transform.flip(flipX: true, child: _decoration('speckles')),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(39 * scale, 24.72, 36 * scale, 19),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.507),
              ),
              padding: EdgeInsets.fromLTRB(20 * scale, 17.37, 23 * scale, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 7.22 * scale),
                      child: _decoration('window_dots'),
                    ),
                  ),
                  const SizedBox(height: 9.18),
                  AspectRatio(
                    aspectRatio: 257.608 / 217.421,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          discovery.image,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 2.34 * scale,
                          height: 72.102 * scale,
                          child: _decoration('photo_shade'),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 9.19 * scale,
                          child: Column(
                            children: [
                              RotatedBox(
                                quarterTurns: 1,
                                child: _decoration('chevron_top'),
                              ),
                              RotatedBox(
                                quarterTurns: 1,
                                child: _decoration('chevron_bottom'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2.8),
                  Text(
                    discovery.title,
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 21,
                      height: 30.913 / 21,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 5.17),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(
                        left: -10.4,
                        top: 0,
                        child: Text(
                          '“',
                          style: TextStyle(
                            fontSize: 27,
                            height: 21.146 / 27,
                            color: Color(0xFF9E9CFE),
                          ),
                        ),
                      ),
                      Text(
                        discovery.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: 15,
                          height: 21.146 / 15,
                          color: Color(0xCC222222),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 19.71),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(104),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
                      ),
                    ),
                    child: TextButton(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      child: const Text('查看内容'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 206.49 * scale,
            top: 0,
            width: 157.025 * scale,
            height: 82.364 * scale,
            child: FittedBox(
              child: SizedBox(
                width: 157.025,
                height: 82.364,
                child: _CategoryTag(label: discovery.category),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      children: [
        Positioned(
          left: 20.99,
          top: 29.724,
          width: 119.96,
          height: 50.51,
          child: Center(
            child: Transform.rotate(
              angle: 10.81 * math.pi / 180,
              child: Container(
                width: 116.558,
                height: 29.174,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12.922),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 3.07,
          top: 18.389,
          width: 24.137,
          height: 23.769,
          child: Center(
            child: Transform.rotate(
              angle: 10.81 * math.pi / 180,
              child: _decoration('tag_left'),
            ),
          ),
        ),
        Positioned(
          left: 133.93,
          top: 53.429,
          width: 17.719,
          height: 20.221,
          child: Center(
            child: Transform.rotate(
              angle: 10.81 * math.pi / 180,
              child: Transform.flip(
                flipX: true,
                child: _decoration('tag_right'),
              ),
            ),
          ),
        ),
        Positioned(
          left: 22.644,
          top: 9.199,
          width: 37.732,
          height: 27.566,
          child: Transform.rotate(
            angle: -4.19 * math.pi / 180,
            child: const Center(
              child: Text(
                '类型',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'PingFang SC',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFDD87),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 35.968,
          top: 36.939,
          width: 93.324,
          height: 37.689,
          child: Transform.rotate(
            angle: 10.81 * math.pi / 180,
            child: Center(
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: 'PingFang SC',
                  fontSize: 14,
                  height: 20.609 / 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
