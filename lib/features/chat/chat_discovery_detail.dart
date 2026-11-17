import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma 448:7103. The published card remains the source for its full text.
class ChatDiscoveryDetail extends StatefulWidget {
  const ChatDiscoveryDetail({super.key, required this.card});
  final Map<String, dynamic> card;

  @override
  State<ChatDiscoveryDetail> createState() => _ChatDiscoveryDetailState();
}

class _ChatDiscoveryDetailState extends State<ChatDiscoveryDetail> {
  final _scroll = ScrollController();
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  void _updateFade() {
    if (!mounted || !_scroll.hasClients) return;
    final more = _scroll.position.extentAfter > 1;
    if (more != _hasMore) setState(() => _hasMore = more);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _text(String key) => (widget.card[key] as String? ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = math.min(
      471.0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom - 32,
    );
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          key: const ValueKey('discovery-expanded-panel'),
          width: math.min(355, media.size.width - 20),
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                left: 5,
                top: 5,
                right: 5,
                bottom: 8,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned.fill(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SvgPicture.asset(
                      'assets/chat/discovery_expanded_background.svg',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _text('title'),
                      style: const TextStyle(
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            _hasMore ? Colors.transparent : Colors.white,
                          ],
                          stops: [0, math.max(0, 1 - 16 / bounds.height), 1],
                        ).createShader(bounds),
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _updateFade(),
                            );
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: const ValueKey('discovery-expanded-scroll'),
                            controller: _scroll,
                            child: SelectableText(
                              _text('content').isNotEmpty
                                  ? _text('content')
                                  : _text('summary'),
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                fontFamily: 'PingFang SC',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 22 / 14,
                                color: Color(0xCCFFFFFF),
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
    );
  }
}
