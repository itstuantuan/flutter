import '../../core/localization/app_localizations.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../discoveries/discovery_detail_page.dart';
import 'chat_service.dart';

/// Figma 431:6636 / 431:6794. Adjacent discovery turns share one horizontal
/// carousel; its vertical position never depends on which card is selected.
class ChatDiscoveryCarousel extends StatefulWidget {
  const ChatDiscoveryCarousel({
    super.key,
    required this.cards,
    this.highlightedMaterialId,
    this.highlightedTurnId,
    this.onPageChanged,
    this.onInteractionChanged,
    this.onReference,
    this.discoveryService,
    this.focusAnimation,
    this.animate = true,
  });

  final List<Map<String, dynamic>> cards;
  final String? highlightedMaterialId;
  final int? highlightedTurnId;
  final VoidCallback? onPageChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final ValueChanged<Map<String, dynamic>>? onReference;
  final ChatService? discoveryService;
  final Animation<double>? focusAnimation;
  final bool animate;

  @override
  State<ChatDiscoveryCarousel> createState() => ChatDiscoveryCarouselState();
}

class ChatDiscoveryCarouselState extends State<ChatDiscoveryCarousel> {
  PageController? _pages;
  double? _viewportFraction;
  int _selected = 0;
  int _navigation = 0;
  bool get _reduceMotion =>
      !widget.animate || MediaQuery.disableAnimationsOf(context);

  Map<String, dynamic>? get selectedCard =>
      widget.cards.elementAtOrNull(_selected);

  bool _focused(Map<String, dynamic> card) =>
      widget.highlightedMaterialId != null &&
      card['materialId'] == widget.highlightedMaterialId &&
      (widget.highlightedTurnId == null ||
          card['_chatTurnId'] == widget.highlightedTurnId);

  Future<bool> revealMaterial(String? materialId, {int? turnId}) {
    final index = widget.cards.indexWhere(
      (card) =>
          (materialId == null || card['materialId'] == materialId) &&
          (turnId == null || card['_chatTurnId'] == turnId),
    );
    return _select(index);
  }

  Future<bool> _select(int index) async {
    final pages = _pages;
    if (index < 0 ||
        index >= widget.cards.length ||
        pages?.hasClients != true) {
      return false;
    }
    final navigation = ++_navigation;
    if (_reduceMotion) {
      pages!.jumpToPage(index);
    } else {
      await pages!.animateToPage(
        index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
    return mounted &&
        navigation == _navigation &&
        identical(pages, _pages) &&
        _selected == index;
  }

  @override
  void didUpdateWidget(covariant ChatDiscoveryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cards.isEmpty) return;
    final oldCard = oldWidget.cards.elementAtOrNull(_selected);
    final id = oldCard?['materialId'];
    final newIndex = id == null
        ? -1
        : widget.cards.indexWhere(
            (c) =>
                c['materialId'] == id &&
                c['_chatTurnId'] == oldCard?['_chatTurnId'],
          );
    final next = newIndex < 0
        ? _selected.clamp(0, widget.cards.length - 1)
        : newIndex;
    if (next != _selected) {
      _selected = next;
      final navigation = ++_navigation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            navigation == _navigation &&
            _pages?.hasClients == true) {
          _pages!.jumpToPage(_selected);
        }
      });
    }
  }

  @override
  void dispose() {
    ++_navigation;
    _pages?.dispose();
    super.dispose();
  }

  Widget _pagination() => Center(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < widget.cards.length; index++)
            Semantics(
              button: true,
              selected: _selected == index,
              label: translate(
                context,
                '第 ${index + 1} 条发现，共 ${widget.cards.length} 条',
              ),
              child: GestureDetector(
                key: ValueKey('discovery-page-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(index),
                child: SizedBox(
                  width: 20,
                  height: 24,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: SvgPicture.asset(
                        _selected == index
                            ? 'assets/chat/discovery_dot_selected.svg'
                            : 'assets/chat/discovery_dot_unselected.svg',
                        key: ValueKey(_selected == index),
                        width: 10,
                        height: 10,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth + 32;
        final cardWidth = math.min(306.0, viewportWidth - 8);
        final fraction = (cardWidth * .925 + 8) / viewportWidth;
        if (_viewportFraction != fraction) {
          final previous = _pages;
          _pages = PageController(
            initialPage: _selected.clamp(0, widget.cards.length - 1),
            viewportFraction: fraction,
          );
          _viewportFraction = fraction;
          if (previous != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => previous.dispose(),
            );
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 129,
              child: OverflowBox(
                minWidth: viewportWidth,
                maxWidth: viewportWidth,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (event) {
                    if (event is ScrollStartNotification &&
                        event.dragDetails != null) {
                      widget.onInteractionChanged?.call(true);
                    }
                    if (event is ScrollEndNotification) {
                      widget.onInteractionChanged?.call(false);
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.cards.length,
                    onPageChanged: (index) {
                      setState(() => _selected = index);
                      widget.onPageChanged?.call();
                    },
                    itemBuilder: (context, index) => AnimatedBuilder(
                      animation: Listenable.merge([
                        _pages!,
                        ?widget.focusAnimation,
                      ]),
                      builder: (context, child) {
                        final page =
                            _pages!.hasClients &&
                                _pages!.position.hasContentDimensions
                            ? _pages!.page ?? _selected.toDouble()
                            : _selected.toDouble();
                        final distance = (page - index).abs().clamp(0.0, 1.0);
                        final focused = _focused(widget.cards[index]);
                        final progress = widget.focusAnimation?.value ?? 0;
                        final pulse =
                            focused &&
                                !_reduceMotion &&
                                progress > 0 &&
                                progress < 1
                            ? math
                                  .pow(math.sin(math.pi * progress * 2), 2)
                                  .toDouble()
                            : 0.0;
                        return Center(
                          child: OverflowBox(
                            minWidth: cardWidth,
                            maxWidth: cardWidth,
                            child: Transform.scale(
                              scale: (1 - .15 * distance) * (1 + .015 * pulse),
                              child: Opacity(
                                opacity: 1 - .12 * distance,
                                child: DecoratedBox(
                                  key: ValueKey('discovery-glow-$index'),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    boxShadow: [
                                      if (pulse > 0)
                                        BoxShadow(
                                          color: const Color(0xFFDC9BFF)
                                              .withValues(alpha: .65 * pulse),
                                          blurRadius: 12 * pulse,
                                          spreadRadius: 1.5 * pulse,
                                        ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ChatDiscoveryCard(
                        card: widget.cards[index],
                        history: widget.cards,
                        discoveryService: widget.discoveryService,
                        height: 121,
                        highlighted: _focused(widget.cards[index]),
                        onInteractionChanged: widget.onInteractionChanged,
                        onReference: widget.onReference,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.cards.length > 1) _pagination(),
          ],
        );
      },
    );
  }
}

class ChatDiscoveryCard extends StatelessWidget {
  const ChatDiscoveryCard({
    super.key,
    required this.card,
    required this.height,
    this.history = const [],
    this.highlighted = false,
    this.onInteractionChanged,
    this.onReference,
    this.discoveryService,
  });

  final Map<String, dynamic> card;
  final double height;
  final List<Map<String, dynamic>> history;
  final bool highlighted;
  final ValueChanged<bool>? onInteractionChanged;
  final ValueChanged<Map<String, dynamic>>? onReference;
  final ChatService? discoveryService;
  static const background = 'assets/chat/discovery_card_background.png';

  String _text(String key) => (card[key] as String? ?? '').trim();

  Future<void> _open(BuildContext context) async {
    onInteractionChanged?.call(true);
    try {
      final reference = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => DiscoveryDetailPage(
            card: card,
            history: history,
            service: discoveryService,
          ),
        ),
      );
      if (reference != null) onReference?.call(reference);
    } finally {
      onInteractionChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _text('summary').isNotEmpty
        ? _text('summary')
        : _text('content');
    final scaler = MediaQuery.textScalerOf(context);
    final largeText = scaler.scale(16) > 20;
    final titleHeight = largeText ? 1.2 : 29.124 / 16;
    final summaryLines =
        ((height - 31 - scaler.scale(16) * titleHeight) /
                (scaler.scale(12) * 20 / 12))
            .floor()
            .clamp(1, 3);
    return Semantics(
      button: true,
      label: '${_text('title')}, ${translate(context, '查看完整内容')}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  background,
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                  excludeFromSemantics: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: titleHeight,
                        color: highlighted
                            ? const Color(0xFFFFDF84)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        widthFactor: 226 / 278,
                        child: Text(
                          summary,
                          maxLines: summaryLines,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(
                            fontFamily: 'PingFang SC',
                            fontSize: 12,
                            height: 20 / 12,
                            color: Color(0xC2FFFFFF),
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
