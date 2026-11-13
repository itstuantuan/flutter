import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_gate.dart';
import '../auth/account_service.dart';

/// The Figma launch composition, followed by the existing application flow.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) {
      _loading = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    try {
      await Future.wait([
        for (final layer in SplashArtwork.layers)
          precacheImage(AssetImage('assets/design/${layer.name}.png'), context),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '启动资源加载失败，请重试');
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, secondaryAnimation) =>
              AuthGate(service: account),
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Scaffold(
          backgroundColor: const Color(0xFF431A90),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _prepare();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        )
      : _ready
      ? const SplashArtwork()
      : const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(backgroundColor: Color(0xFF431A90)),
        );
}

/// Individually exported decorative layers preserve the original lettering,
/// masks and glows. Coordinates include Figma's parent clipping/effect bounds.
/// System status and gesture bars are supplied by the device, not painted here.
class SplashArtwork extends StatefulWidget {
  const SplashArtwork({super.key, this.animate = true});

  final bool animate;

  static const layers = <({String name, Rect rect})>[
    (name: 'splash_background', rect: Rect.fromLTWH(0, 1, 375, 811)),
    (name: 'splash_character', rect: Rect.fromLTWH(54, 253, 262, 447)),
    (name: 'splash_ribbon', rect: Rect.fromLTWH(0, 544, 375, 268)),
    (name: 'splash_shadow', rect: Rect.fromLTWH(81.1, 634.1, 235.8, 104.8)),
    (name: 'splash_brand', rect: Rect.fromLTWH(32, 141, 310, 85.727)),
  ];

  @override
  State<SplashArtwork> createState() => _SplashArtworkState();
}

class _SplashArtworkState extends State<SplashArtwork>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  late final _ribbon = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  late final _backRibbon = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  void _syncAnimations() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _backRibbon.stop();
      _backRibbon.value = 0;
      _ribbon.stop();
      _ribbon.value = 0;
      _idle.stop();
      _idle.value = 0;
    } else {
      _entrance.forward();
      if (!_idle.isAnimating) _idle.repeat();
      if (!_ribbon.isAnimating) _ribbon.repeat();
      if (!_backRibbon.isAnimating) _backRibbon.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant SplashArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) _entrance.value = 0;
      _syncAnimations();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _idle.dispose();
    _ribbon.dispose();
    _backRibbon.dispose();
    super.dispose();
  }

  Widget _animateLayer(String name, Widget child) {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _idle]),
      child: child,
      builder: (context, child) {
        final enter = Curves.easeOutCubic.transform(_entrance.value);
        final remaining = 1 - enter;
        final float = 1 - math.cos(_idle.value * math.pi * 2);
        final offset = switch (name) {
          'splash_character' => Offset(0, remaining * 45 - float * 2),
          'splash_brand' => Offset(0, remaining * 14),
          'ribbon_back' => Offset(-375 * remaining, 0),
          'splash_ribbon' => Offset(375 * remaining, 0),
          _ => Offset.zero,
        };
        return Opacity(
          opacity: name == 'splash_brand' || name == 'splash_character'
              ? enter
              : 1,
          child: Transform.translate(offset: offset, child: child),
        );
      },
    );
  }

  Widget _ribbonArtwork(Widget still) {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      return still;
    }
    // One complete phrase and emblem. Adjacent copies overlap in the empty
    // margin so the cropped export can travel along its original 30° slope.
    const stride = 314.0;
    const rise = stride * 0.5773502692;
    return AnimatedBuilder(
      animation: _ribbon,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = -2; index <= 2; index++)
            Positioned(
              left: (index + _ribbon.value) * stride,
              top: -(index + _ribbon.value) * rise,
              width: 330,
              height: 268,
              child: ClipRect(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0, 16 / 330, 1],
                  ).createShader(bounds),
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 375,
                    maxWidth: 375,
                    minHeight: 268,
                    maxHeight: 268,
                    child: still,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF431A90),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF431A90),
      body: Semantics(
        label: 'ViiTor Bot. Your AI friend and digital twin. Welcome to ViiTor Bot!',
        image: true,
        child: ExcludeSemantics(
          child: SizedBox.expand(
            child: FittedBox(
              // Fill every screen ratio without stretching the illustration.
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 375,
                height: 812,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final layer in SplashArtwork.layers)
                      Positioned.fromRect(
                        rect: layer.rect,
                        child: _animateLayer(
                          layer.name,
                          _layerImage(layer.name),
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
  );

  Widget _layerImage(String name) {
    final image = RepaintBoundary(
      child: Image.asset(
        'assets/design/$name.png',
        fit: name == 'splash_character' ? BoxFit.cover : BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );
    if (name == 'splash_background' &&
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          image,
          RepaintBoundary(
            child: CustomPaint(painter: _BackRibbonPainter(_backRibbon)),
          ),
        ],
      );
    }
    return name == 'splash_ribbon' ? _ribbonArtwork(image) : image;
  }
}

/// Covers the baked-in lettering at its original angle; the character is
/// painted above this background layer, so the moving text passes behind her.
class _BackRibbonPainter extends CustomPainter {
  _BackRibbonPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;
  final TextPainter _label = TextPainter(
    text: const TextSpan(
      text: 'ViiTor Bot-Your AI friend and digital twin.',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        fontFamily: 'Arial',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 375, size.height / 811);
    // Coordinates are relative to the background export (one pixel below
    // the artboard origin), including its original clipped ribbon edges.
    final band = Path()
      ..moveTo(0, 300)
      ..lineTo(375, 361)
      ..lineTo(375, 409)
      ..lineTo(0, 348)
      ..close();
    canvas.clipPath(band);
    canvas.drawPaint(
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFBA44FC), Color(0xFF8C67FF)],
        ).createShader(const Rect.fromLTWH(0, 300, 375, 109)),
    );
    canvas.translate(0, 300);
    canvas.rotate(math.atan2(61, 375));
    final stride = _label.width + 36;
    final shift = progress.value * stride;
    for (var index = -1; index <= 2; index++) {
      _label.paint(
        canvas,
        Offset(16 + index * stride - shift, (47.4 - _label.height) / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackRibbonPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
