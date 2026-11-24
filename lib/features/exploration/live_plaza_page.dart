import 'dart:async';

import 'package:flutter/material.dart';

import '../plaza/plaza_page.dart';
import '../plaza/plaza_discovery.dart';
import '../shared/app_toast.dart';
import 'exploration_controller.dart';
import 'discovery_policy.dart';

/// Keeps the existing local plaza stories; only completion presentation uses the server.
class LivePlazaPage extends StatefulWidget {
  const LivePlazaPage({
    super.key,
    required this.controller,
    required this.taskId,
    required this.onChat,
    required this.onOpenDiscovery,
  });
  final ExplorationController controller;
  final String? taskId;
  final Future<void> Function(bool voice) onChat;
  final Future<void> Function(Map<String, dynamic> card) onOpenDiscovery;
  @override
  State<LivePlazaPage> createState() => _LivePlazaPageState();
}

class _LivePlazaPageState extends State<LivePlazaPage>
    with WidgetsBindingObserver {
  bool _showing = false, _scheduled = false;
  String? _terminalShown;
  String? _lastPresentedTask;
  ValueNotifier<List<PlazaDiscovery>>? _dialogCards;
  final _presentedHere = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_refresh);
    if (widget.taskId != null) widget.controller.watchPlaza(widget.taskId!);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LivePlazaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      widget.controller.stopWatchingPlaza();
      _terminalShown = null;
      if (widget.taskId != null) widget.controller.watchPlaza(widget.taskId!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_refresh);
    widget.controller.stopWatchingPlaza();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          (!_showing && ModalRoute.of(context)?.isCurrent != true) ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      if (_showing) {
        _appendPendingCards();
        return;
      }
      final events = widget.controller.pendingEvents
          .where(
            (event) =>
                widget.taskId == null || event['taskId'] == widget.taskId,
          )
          .where((event) => !_presentedHere.contains(event['eventId']))
          .toList();
      if (events.isNotEmpty) {
        unawaited(_present(events.first, automatic: true));
        return;
      }
      final progress = widget.controller.progress;
      final phase = progress['phase'];
      if ((phase == 'empty' || phase == 'failed') && _terminalShown != phase) {
        _terminalShown = phase as String;
        _notice(phase == 'empty' ? '这次没有新的发现，可以返回首页再次出发。' : '这次探索未完成，请返回首页重试。');
      }
    });
    // A network event can arrive while the page is otherwise idle. A post-frame
    // callback alone does not request a frame, so explicitly schedule one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _present(
    Map<String, dynamic> event, {
    bool automatic = false,
  }) async {
    if (_showing) return;
    _showing = true;
    _lastPresentedTask = event['taskId'] as String?;
    final eventId = event['eventId'] as String?;
    if (eventId != null) _presentedHere.add(eventId);
    final cards = automatic
        ? widget.controller.unseenCards(event)
        : (event['cards'] as List).cast<Map>().take(maxDiscoveryCards);
    if (cards.isEmpty) {
      try {
        await widget.controller.markDisplayed(event);
      } catch (e) {
        await widget.controller.reportError(e);
      } finally {
        _showing = false;
        if (mounted) _refresh();
      }
      return;
    }
    final discoveries = cards.map(_discovery).toList();
    final updates = ValueNotifier(discoveries);
    _dialogCards = updates;
    try {
      final selected = await showPlazaDiscoveries(
        context,
        discoveries: discoveries,
        updates: updates,
        onPresented: eventId == null
            ? null
            : () => unawaited(
                widget.controller
                    .markDisplayed({...event, 'cards': cards.toList()})
                    .catchError((Object e) => widget.controller.reportError(e)),
              ),
      );
      _dialogCards = null;
      if (!mounted || selected == null) return;
      final taskId = event['taskId'] as String?;
      if (taskId == null || taskId.isEmpty) {
        _notice('这条发现缺少定位信息');
        return;
      }
      final source = selected.sourceCard;
      if (source == null) {
        _notice('暂时无法读取这条发现，请稍后重试');
        return;
      }
      await widget.onOpenDiscovery({...source, 'taskId': taskId});
    } finally {
      _dialogCards = null;
      updates.dispose();
      _showing = false;
      if (mounted) _refresh();
    }
  }

  PlazaDiscovery _discovery(Map card) => PlazaDiscovery(
    sourceCard: Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(card)),
    title: card['title'] as String? ?? '',
    body: card['content'] as String? ?? card['summary'] as String? ?? '',
    category: (card['tags'] as List? ?? []).join(' · '),
    coverUrl: card['coverUrl'] as String?,
    materialId: card['materialId'] as String?,
  );

  void _appendPendingCards() {
    final updates = _dialogCards;
    if (updates == null) return; // The user has opened a discovery detail.
    final events = widget.controller.pendingEvents
        .where(
          (event) =>
              event['taskId'] == _lastPresentedTask &&
              !_presentedHere.contains(event['eventId']),
        )
        .toList();
    if (events.isEmpty) return;
    final cards = [...updates.value];
    final known = cards
        .map((card) => card.materialId)
        .whereType<String>()
        .toSet();
    for (final event in events) {
      final eventId = event['eventId'] as String;
      _presentedHere.add(eventId);
      for (final card in widget.controller.unseenCards(event)) {
        final material = card['materialId'];
        if (material is String && !known.add(material)) continue;
        cards.add(_discovery(card));
      }
    }
    updates.value = cards;
    // Acknowledge only after the updated carousel and dots have rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogCards != updates) {
        for (final event in events) {
          _presentedHere.remove(event['eventId']);
        }
        if (mounted) _refresh();
        return;
      }
      for (final event in events) {
        unawaited(
          widget.controller
              .markDisplayed(event)
              .catchError(
                (Object error) => widget.controller.reportError(error),
              ),
        );
      }
    });
  }

  bool _loadingDiscovery = false;

  Future<void> _openDiscovery() async {
    if (_showing || _loadingDiscovery) return;
    final taskId =
        widget.taskId ??
        widget.controller.activeTaskId ??
        _lastPresentedTask ??
        widget.controller.cards.firstOrNull?['taskId'] as String?;
    if (taskId == null) {
      _notice('当前暂无探索发现');
      return;
    }
    _loadingDiscovery = true;
    try {
      final result = await widget.controller.discoveryResult(taskId);
      if (!mounted || _showing) return;
      if (result == null) {
        _notice('当前探索暂无返回内容，请稍后再试');
        return;
      }
      await _present(result);
    } catch (error) {
      await widget.controller.reportError(error);
      if (mounted) _notice('暂时无法读取探索内容，请稍后重试');
    } finally {
      _loadingDiscovery = false;
    }
  }

  void _notice(String message) => showAppToast(context, message);

  Future<void> _chat(bool voice) async {
    await widget.onChat(voice);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PlazaPage(
      displayName: widget.controller.chat.displayName,
      onChat: () => _chat(false),
      onVoice: () => _chat(true),
      onDiscovery: _openDiscovery,
      explorationPhase: widget.taskId == null
          ? null
          : widget.controller.progress['phase'] as String? ?? 'loading',
      explorationElapsedSeconds:
          widget.controller.square['elapsedSeconds'] is num
          ? (widget.controller.square['elapsedSeconds'] as num).toInt()
          : null,
      progressUnavailable: widget.controller.progressUnavailable,
    ),
  );
}
