import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player/video_player.dart';

import 'phone_login_artwork.dart';

class NamePage extends StatefulWidget {
  const NamePage({super.key, required this.onContinue, this.initialName = ''});
  final Future<void> Function(String name) onContinue;
  final String initialName;
  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  final _video = VideoPlayerController.asset(
    'assets/login/name_character.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _started = false;
  bool _videoReady = false;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _entrance.addStatusListener(_focusAfterEntrance);
    _prepareVideo();
  }

  void _focusAfterEntrance(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entrance.removeStatusListener(_focusAfterEntrance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_busy && ModalRoute.of(context)?.isCurrent != false) {
        _nameFocus.requestFocus();
      }
    });
  }

  Future<void> _prepareVideo() async {
    try {
      await _video.initialize();
      if (!mounted) return;
      await _video.setVolume(0);
      await _video.setLooping(true);
      if (!mounted) return;
      await _video.play();
      if (mounted) setState(() => _videoReady = true);
    } on PlatformException {
      // Keep the first frame visible when decoding is unavailable.
    } on MissingPluginException {
      // A platform without a video backend can still complete registration.
    } on UnimplementedError {
      // The platform has no registered video player.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_started) {
      _entrance.forward();
    }
    _started = true;
  }

  Widget _reveal(int index, Widget child) {
    final progress = _entrance.drive(
      CurveTween(
        curve: Interval(
          index * .14,
          index * .14 + .44,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 32 * (1 - progress.value)),
        child: Opacity(opacity: progress.value, child: child),
      ),
    );
  }

  late final _name = TextEditingController(text: widget.initialName);
  bool _busy = false;
  String? _error;
  Future<void> _continue() async {
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onContinue(_name.text.trim());
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _video.dispose();
    _nameFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF1B0C36),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, bounds) {
          final media = MediaQuery.of(context);
          final width = math.min(
            bounds.maxWidth - media.padding.horizontal,
            420.0,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: math.max(0, bounds.maxHeight - media.viewInsets.bottom),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  math.max(media.padding.top, 42),
                  16,
                  math.max(media.padding.bottom, 16),
                ),
                child: Column(
                  children: [
                    _reveal(
                      0,
                      SizedBox.square(
                        dimension: width * .46,
                        child: ShaderMask(
                          shaderCallback: (rect) => const RadialGradient(
                            radius: .69,
                            colors: [Colors.white, Colors.transparent],
                            stops: [.76, 1],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: _videoReady
                              ? VideoPlayer(_video)
                              : Image.asset('assets/login/name_character.jpg'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _reveal(
                      1,
                      Semantics(
                        header: true,
                        child: const Text(
                          '初次见面，怎么称呼呀',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _reveal(
                      2,
                      const Text(
                        '留下你的名字，以后我就知道怎么叫你啦～',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: 1,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 23),
                    _reveal(
                      3,
                      SizedBox(
                        height: 60,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.fill,
                                child: loginSvg(
                                  'name_field',
                                  width: 343,
                                  height: 60,
                                ),
                              ),
                            ),
                            Center(
                              child: TextField(
                                key: const ValueKey('login-name'),
                                controller: _name,
                                focusNode: _nameFocus,
                                enabled: !_busy,
                                maxLength: 40,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.nickname],
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _continue(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '请输入你的名字',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF514762),
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 26,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _reveal(
                      4,
                      Opacity(
                        opacity: _name.text.trim().isEmpty ? .24 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(104),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
                            ),
                          ),
                          child: TextButton(
                            key: const ValueKey('name-next'),
                            onPressed: _busy || _name.text.trim().isEmpty
                                ? null
                                : _continue,
                            style: TextButton.styleFrom(
                              overlayColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 58),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '继续',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFB2DA)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
