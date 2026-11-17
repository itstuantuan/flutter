import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const designInterests = ['音乐', '游戏', '影视', '动漫', '旅游', '宠物', '美食', '阅读', '吃瓜'];

class InterestsPage extends StatefulWidget {
  const InterestsPage({
    super.key,
    this.initialSelection = const [],
    required this.onStart,
  });
  final List<String> initialSelection;
  final Future<bool> Function(List<String>) onStart;
  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage>
    with SingleTickerProviderStateMixin {
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  late final Set<String> _selected = widget.initialSelection
      .where(designInterests.contains)
      .toSet();
  bool _busy = false;
  final Map<String, int> _ripples = {};
  String? _error;
  void _toggle(String value) {
    if (_busy) return;
    setState(() {
      _ripples[value] = (_ripples[value] ?? 0) + 1;
      _selected.contains(value)
          ? _selected.remove(value)
          : _selected.add(value);
      _error = null;
    });
  }

  Future<void> _start() async {
    if (_busy || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.onStart(_selected.toList());
      if (mounted && !ok) setState(() => _error = '保存失败，请重试');
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _svg(String name, double w, double h) => SvgPicture.asset(
    'assets/design/interest_$name.svg',
    width: w,
    height: h,
    excludeFromSemantics: true,
  );
  Widget _bubbles(double width, bool large) {
    const slots = [
      (55.0, 27.0, 91.0),
      (163.0, 0.0, 100.0),
      (277.0, 40.0, 100.0),
      (-7.0, 118.0, 100.0),
      (103.0, 129.0, 109.0),
      (228.0, 145.0, 100.0),
      (24.0, 234.0, 91.0),
      (131.0, 254.0, 100.0),
      (250.0, 254.0, 100.0),
    ];
    Widget bubble(int i, double diameter) {
      final label = designInterests[i];
      final selected = _selected.contains(label);
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          key: ValueKey('interest-$label'),
          onTap: _busy ? null : () => _toggle(label),
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              final phase = _float.value * 2 * math.pi + i * 1.7;
              return Transform.translate(
                key: ValueKey('interest-motion-$label'),
                offset: _reduceMotion
                    ? Offset.zero
                    : Offset(math.sin(phase) * 5, math.cos(phase) * 9),
                child: child,
              );
            },
            child: AnimatedScale(
              scale: _reduceMotion || selected ? 1 : .96,
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (!_reduceMotion && (_ripples[label] ?? 0) > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('ripple-$label-${_ripples[label]}'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 950),
                          builder: (_, progress, _) => CustomPaint(
                            painter: _InterestRipplePainter(progress),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: diameter,
                    height: diameter,
                    child: AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      child: FittedBox(
                        key: ValueKey(selected),
                        child: _svg(
                          selected
                              ? (i == 4 ? 'selected_large' : 'selected')
                              : (i == 0 || i == 6 ? 'small' : 'circle'),
                          slots[i].$3,
                          slots[i].$3,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 7,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: _svg('star', 16, 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (large) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 10,
          runSpacing: 12,
          children: [for (var i = 0; i < slots.length; i++) bubble(i, 100)],
        ),
      );
    }
    final scale = width / 375;
    return SizedBox(
      height: 378 * scale,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < slots.length; i++)
            Positioned(
              left: slots[i].$1 * scale,
              top: (slots[i].$2 + 12) * scale,
              width: slots[i].$3 * scale,
              height: slots[i].$3 * scale,
              child: bubble(i, slots[i].$3 * scale),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF1B083E),
      body: LayoutBuilder(
        builder: (context, bounds) {
          final safe = MediaQuery.paddingOf(context);
          final width = math.min(bounds.maxWidth - safe.horizontal, 420.0);
          final large = MediaQuery.textScalerOf(context).scale(16) > 20;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 375,
                      height: 812,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 34,
                            top: 0,
                            width: 341,
                            height: 445,
                            child: Image.asset(
                              'assets/design/interest_dots.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 219,
                            width: 375,
                            height: 593,
                            child: Image.asset(
                              'assets/design/interest_character.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            width: 375,
                            height: 408,
                            child: Image.asset(
                              'assets/design/interest_glow.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: width,
                  child: SafeArea(
                    left: false,
                    right: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 37),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    children: [
                                      Stack(
                                        children: [
                                          Positioned(
                                            left: 5,
                                            bottom: 0,
                                            child: _svg(
                                              'underline',
                                              210.5,
                                              22.5,
                                            ),
                                          ),
                                          const Text(
                                            '你对什么感兴趣?',
                                            style: TextStyle(
                                              fontSize: 26,
                                              height: 1.1,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Transform.rotate(
                                        angle: -13.78 * math.pi / 180,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF5B72E9),
                                                Color(0xFFE74A8B),
                                              ],
                                            ),
                                          ),
                                          child: const Text(
                                            'love',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
                                  child: Text(
                                    '选择你喜欢的内容,可多选:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 20 / 14,
                                      color: Color(0x80FFFFFF),
                                    ),
                                  ),
                                ),
                                _bubbles(width, large),
                                const SizedBox(height: 26),
                                Center(
                                  child: Text(
                                    '-  选择${_selected.length},还可以选择${9 - _selected.length}个 -',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0x94FFFFFF),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, bounds) {
                                      const gap = 12.0;
                                      final minWidth =
                                          MediaQuery.textScalerOf(context)
                                              .scale(24) +
                                          37;
                                      final columns =
                                          ((bounds.maxWidth + gap) /
                                                  (minWidth + gap))
                                              .floor()
                                              .clamp(1, 4);
                                      final chipWidth =
                                          (bounds.maxWidth -
                                              gap * (columns - 1)) /
                                          columns;
                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: 11,
                                        children: [
                                          for (final label in _selected)
                                            SizedBox(
                                              width: chipWidth,
                                              child: Semantics(
                                                button: true,
                                                label: '移除$label',
                                                child: GestureDetector(
                                                  key: ValueKey(
                                                    'remove-$label',
                                                  ),
                                                  onTap: _busy
                                                      ? null
                                                      : () => _toggle(label),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0x17FFFFFF,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            209,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            label,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                  letterSpacing:
                                                                      1,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 7,
                                                        ),
                                                        _svg('remove', 10, 10),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFFB2DA),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 112,
                                child: _button(
                                  'all',
                                  _selected.length == designInterests.length
                                      ? '取消全选'
                                      : '全选',
                                  Colors.black,
                                  () => setState(() {
                                    final allSelected =
                                        _selected.length ==
                                        designInterests.length;
                                    _selected.clear();
                                    if (!allSelected) {
                                      _selected.addAll(designInterests);
                                    }
                                    _error = null;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                flex: 222,
                                child: Opacity(
                                  opacity: _selected.isEmpty ? .24 : 1,
                                  child: _button(
                                    'start',
                                    _busy ? '保存中…' : '开始探索',
                                    Colors.white,
                                    _selected.isEmpty ? null : _start,
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
            ],
          );
        },
      ),
    ),
  );
  Widget _button(
    String asset,
    String label,
    Color color,
    VoidCallback? onTap,
  ) => Stack(
    children: [
      Positioned.fill(
        child: FittedBox(
          fit: BoxFit.fill,
          child: _svg(asset, asset == 'all' ? 112 : 222, 50),
        ),
      ),
      TextButton(
        key: ValueKey('interests-$asset'),
        onPressed: _busy ? null : onTap,
        style: TextButton.styleFrom(
          overlayColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _InterestRipplePainter extends CustomPainter {
  const _InterestRipplePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 2; i++) {
      final t = (progress - i * .18) / (1 - i * .18);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - t) + .5
        ..color = (i == 0 ? const Color(0xFF81DFFF) : const Color(0xFFEBA0FF))
            .withValues(alpha: .65 * (1 - t));
      canvas.drawCircle(center, radius * (.96 + .48 * eased), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InterestRipplePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
