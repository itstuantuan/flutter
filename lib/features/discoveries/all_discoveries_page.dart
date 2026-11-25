import '../../core/localization/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../chat/chat_service.dart';
import '../shared/design_scene.dart';
import 'discovery_history.dart';

String discoveryCategory(Map<String, dynamic> card) {
  const labels = {
    'pets': '宠物',
    'music': '音乐',
    'film_tv': '影视',
    'travel': '旅行',
    'games': '游戏',
    'anime': '动漫',
    'food': '美食',
    'reading': '阅读',
    'trending': '吃瓜',
  };
  final tags = card['tags'];
  final raw =
      card['category'] ?? (tags is List && tags.isNotEmpty ? tags.first : null);
  return raw is String ? labels[raw] ?? raw : '';
}

String discoveryTime(Map<String, dynamic> card, {DateTime? now}) {
  final raw =
      (card['state'] as Map?)?[card['_history'] == true
          ? 'lastViewTime'
          : 'firstRecommendedTime'] ??
      card['createdAt'] ??
      card['completedAt'];
  final date = raw is DateTime
      ? raw
      : raw is num
      ? DateTime.fromMillisecondsSinceEpoch(
          (raw < 100000000000 ? raw * 1000 : raw).toInt(),
        )
      : raw is String
      ? DateTime.tryParse(raw)
      : null;
  if (date == null) return card['timeLabel'] as String? ?? '';
  final local = date.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final stamp = DateTime(local.year, local.month, local.day);
  if (stamp == day) {
    return '今天 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (stamp == DateTime(today.year, today.month, today.day - 1)) return '昨天';
  final md =
      '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  return local.year == today.year ? md : '${local.year}-$md';
}

class AllDiscoveriesPage extends StatefulWidget {
  const AllDiscoveriesPage({
    super.key,
    required this.cards,
    required this.onOpen,
    this.service,
    this.onlyHistory = false,
  });
  final List<Map<String, dynamic>> cards;
  final FutureOr<void> Function(Map<String, dynamic>) onOpen;
  final ChatService? service;
  final bool onlyHistory;

  @override
  State<AllDiscoveriesPage> createState() => _AllDiscoveriesPageState();
}

class _AllDiscoveriesPageState extends State<AllDiscoveriesPage> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  DiscoveryHistory? _history;
  bool _searching = false, _opening = false, _onlyHistory = false;

  @override
  void initState() {
    super.initState();
    _onlyHistory = widget.onlyHistory;
    if (widget.service case final service?) {
      _history = DiscoveryHistory(service: service, initial: widget.cards)
        ..history = _onlyHistory
        ..addListener(_refresh);
      unawaited(_history!.loadMore());
    }
    _scroll.addListener(_loadAtEnd);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _loadAtEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 180 &&
        _history?.error == null) {
      unawaited(_history?.loadMore());
    }
  }

  @override
  void dispose() {
    _history?.removeListener(_refresh);
    _history?.dispose();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(Map<String, dynamic> card) async {
    if (_opening || card['available'] == false) return;
    _opening = true;
    try {
      await widget.onOpen(card);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final cards = (_history?.cards ?? widget.cards)
        .where(
          (card) =>
              _history != null ||
              '${card['title'] ?? ''} ${discoveryCategory(card)} ${translate(context, discoveryCategory(card))}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final history = _history;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF18191E),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
              child: DesignScene(
                asset: 'assets/home/discoveries_background.png',
                sourceRect: Rect.fromLTWH(-64.35, -29, 503.7, 895),
                semanticLabel: '',
              ),
            ),
            const ColoredBox(color: Color(0x40000000)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: SizedBox(
                      height: 49,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: translate(context, '返回'),
                            onPressed: () {
                              if (_searching) {
                                setState(() {
                                  _searching = false;
                                  _query.clear();
                                  unawaited(_history?.search(''));
                                });
                                FocusScope.of(context).unfocus();
                              } else {
                                Navigator.maybePop(context);
                              }
                            },
                            icon: SvgPicture.asset(
                              'assets/home/discoveries_back.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          if (_history != null && !_searching)
                            IconButton(
                              tooltip: _onlyHistory ? '全部发现' : '浏览历史',
                              icon: Icon(
                                _onlyHistory ? Icons.list : Icons.history,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() => _onlyHistory = !_onlyHistory);
                                unawaited(
                                  _history!.search(
                                    _query.text,
                                    onlyHistory: _onlyHistory,
                                  ),
                                );
                              },
                            ),
                          if (_searching)
                            Expanded(
                              child: Container(
                                height: 40,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.only(left: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AFFFFFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x33FFFFFF),
                                    width: .5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/chat/search_small.svg',
                                      width: 11.2,
                                      height: 11.9,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        key: const ValueKey('discovery-search'),
                                        controller: _query,
                                        autofocus: true,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        onChanged: (value) {
                                          setState(() {});
                                          unawaited(_history?.search(value));
                                        },
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: translate(context, '搜索发现'),
                                          hintStyle: TextStyle(
                                            color: Colors.white54,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: translate(context, '清除搜索'),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 28,
                                            height: 40,
                                          ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          setState(() => _query.clear()),
                                      icon: SvgPicture.asset(
                                        'assets/chat/search_clear.svg',
                                        width: 12,
                                        height: 12,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                      child: VerticalDivider(
                                        width: 1,
                                        color: Colors.white38,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          FocusScope.of(context).unfocus(),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(45, 40),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const AppText(
                                        '搜索',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            const Spacer(),
                            IconButton(
                              tooltip: translate(context, '搜索发现'),
                              onPressed: () =>
                                  setState(() => _searching = true),
                              icon: SvgPicture.asset(
                                'assets/home/discoveries_search.svg',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('all-discoveries-list'),
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DiscoveryRow(
                              card: card,
                              onTap: () => _open(card),
                            ),
                          ),
                        if (cards.isEmpty && history?.loading != true)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 72,
                              horizontal: 24,
                            ),
                            child: AppText(
                              query.isEmpty ? '还没有发现，去逛一逛吧' : '没有找到相关发现',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        if (history?.loading == true)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFCAADFB),
                                ),
                              ),
                            ),
                          ),
                        if (history != null &&
                            !history.loading &&
                            (history.hasMore || history.error != null))
                          TextButton(
                            onPressed: history.loadMore,
                            child: AppText(
                              history.error ?? '加载更多发现',
                              style: const TextStyle(color: Color(0xFFCAADFB)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryRow extends StatelessWidget {
  const _DiscoveryRow({required this.card, required this.onTap});
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  String get _asset =>
      card['imageAsset'] as String? ??
      switch (discoveryCategory(card)) {
        '宠物' => 'assets/home/discoveries_pets.png',
        '音乐' => 'assets/home/discoveries_music.png',
        '旅行' || '旅游' => 'assets/home/discoveries_travel.png',
        _ => 'assets/home/discoveries_film.png',
      };

  @override
  Widget build(BuildContext context) {
    final title = card['title'] as String? ?? '';
    final metadata = [
      translate(context, discoveryCategory(card)),
      translate(context, discoveryTime(card)),
    ].where((s) => s.isNotEmpty).join('·');
    final url = card['coverUrl'];
    final fallback = Opacity(
      opacity: .71,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.white],
          stops: [0, .8],
        ).createShader(rect),
        child: Image.asset(
          _asset,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
    );
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 161 / 375,
                    heightFactor: 1,
                    child:
                        url is String &&
                            Uri.tryParse(url)?.host.isNotEmpty == true &&
                            url.startsWith('https://')
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => fallback,
                            frameBuilder:
                                (context, child, frame, synchronous) =>
                                    frame == null
                                    ? fallback
                                    : Opacity(
                                        opacity: .71,
                                        child: ShaderMask(
                                          blendMode: BlendMode.dstIn,
                                          shaderCallback: (rect) =>
                                              const LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white,
                                                ],
                                                stops: [0, .8],
                                              ).createShader(rect),
                                          child: child,
                                        ),
                                      ),
                          )
                        : fallback,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 77),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x24FFFFFF), width: .5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const style = TextStyle(
                          color: Colors.white,
                          fontFamily: 'PingFang SC',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 25 / 18,
                          letterSpacing: .36,
                        );
                        final scaler = MediaQuery.textScalerOf(context);
                        final measure = TextPainter(
                          text: TextSpan(text: title, style: style),
                          textDirection: Directionality.of(context),
                          textScaler: scaler,
                        )..layout();
                        final multiline = measure.width > constraints.maxWidth;
                        measure.dispose();
                        return SizedBox(
                          width: multiline && scaler.scale(18) <= 22
                              ? constraints.maxWidth * 275 / 342
                              : constraints.maxWidth,
                          child: Text(title, style: style),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      metadata,
                      style: const TextStyle(
                        color: Color(0x73FFFFFF),
                        fontFamily: 'PingFang SC',
                        fontSize: 12,
                        height: 17 / 12,
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
