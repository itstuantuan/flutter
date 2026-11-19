import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'chat_artwork.dart';
import 'chat_discovery_carousel.dart';

import 'chat_message.dart';
import 'chat_time.dart';
import 'chat_transcript.dart';
import 'chat_typewriter.dart';
import 'voice_capture.dart';
import 'system_dictation.dart';
import 'voice_playback.dart';
import 'voice_storage.dart';

/// Shared welcome/conversation UI. Microphone access starts only on a tap.
/// Audio is recorded locally; a server upload is not implied by saving it.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.onExit,
    required this.onExplore,
    this.messages = const [],
    this.onSend,
    this.onVoiceRecorded,
    this.voiceCapture,
    this.useSystemDictation = false,
    this.dictation,
    this.voicePlayback,
    this.name = 'Pal',
    this.exitLabel = '跳过',
    this.initialDraft = '',
    this.initialRecordingPreview = false,
    this.startRecordingOnOpen = false,
    this.animate = true,
    this.busy = false,
    this.lockComposer = false,
    this.error,
    this.timeLabel,
    this.returningUser = false,
    this.showWelcome = true,
    this.anchorTurnId,
    this.anchorMaterialId,
    this.locationRevision = 0,
    this.onAnchorVisible,
    this.onDiscoveryVisible,
    this.onLoadOlderMessages,
    this.loadingOlderMessages = false,
  });
  final bool returningUser, showWelcome;
  final int? anchorTurnId;
  final String? anchorMaterialId;
  final int locationRevision;
  final VoidCallback? onAnchorVisible;
  final ValueChanged<String>? onDiscoveryVisible;
  final VoidCallback? onLoadOlderMessages;
  final bool loadingOlderMessages;
  final VoidCallback onExit, onExplore;
  final List<ChatMessage> messages;
  final FutureOr<bool> Function(String text)? onSend;
  final Future<bool> Function(VoiceClip clip)? onVoiceRecorded;
  final bool useSystemDictation;
  final SystemDictation? dictation;
  final VoiceCapture? voiceCapture;
  final VoicePlayback? voicePlayback;
  final String name, exitLabel, initialDraft;
  final bool initialRecordingPreview, startRecordingOnOpen, animate, busy;
  final bool lockComposer;
  final String? error, timeLabel;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final _input = TextEditingController(text: widget.initialDraft);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final _localMessages = [...widget.messages];
  late bool _recordingPreview = widget.initialRecordingPreview;
  late final _voice = widget.voiceCapture ?? VoiceCapture();
  late final _dictation = widget.dictation ?? SystemDictation.shared;
  bool _dictating = false;
  bool _dictationSendPending = false;
  String _draftBeforeDictation = '';
  VoicePlayback? _playback;
  StreamSubscription<void>? _playbackComplete;
  String? _playingPath;
  bool _sendingText = false;
  bool _sendingRecording = false;
  final _turnKeys = <int, GlobalKey>{};
  final _textKeys = <int, GlobalKey>{};
  final _discoveryKeys = <int, GlobalKey<ChatDiscoveryCarouselState>>{};
  Timer? _highlightTimer;
  Offset _exploreBannerOffset = Offset.zero;
  bool _exploreBannerCollapsed = false;
  late final _focusPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  final _typingTurns = <int>{};
  int _anchorRequest = 0;
  bool _locatingAnchor = false;
  bool _anchorPending = false;
  final _reportedTasks = <String>{};
  int? _highlightedTurn;
  Future<bool>? _voiceSave;
  String? _error;
  final _ephemeralMessages = <ChatMessage>[];

  bool get _recording =>
      _recordingPreview || _voice.recording || _voice.pending != null;
  int get _seconds => _dictating || _dictationSendPending
      ? _dictation.elapsed.inSeconds
      : _voice.elapsed.inSeconds;
  List<ChatMessage> get _messages => [
    ...widget.onSend == null ? _localMessages : widget.messages,
    ..._ephemeralMessages,
  ];
  List<ChatTranscriptEntry> get _entries => chatTranscriptEntries(_messages);

  int? _renderedTurnId(int? turnId) =>
      _entries
          .where((entry) => entry.containsTurn(turnId))
          .firstOrNull
          ?.message
          .turnId ??
      turnId;

  bool get _busy =>
      _dictationSendPending ||
      widget.lockComposer ||
      widget.busy ||
      _sendingText ||
      _sendingRecording ||
      _voice.busy ||
      (widget.useSystemDictation && _dictation.busy);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice.addListener(_refreshVoice);
    if (widget.useSystemDictation) _dictation.addListener(_refreshDictation);
    _scroll.addListener(_scheduleVisible);
    if (widget.anchorTurnId != null) _scrollToAnchor();
    _scheduleVisible();
    if (widget.startRecordingOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startRecording());
      });
    }
  }

  void _refreshDictation() {
    if (!mounted || !_dictating) return;
    setState(() {
      _error = _dictation.error;
      // A completed utterance stays behind the original voice controls until
      // the user explicitly sends or cancels it.
      if (!_dictation.active &&
          !_dictation.busy &&
          _dictation.text.trim().isEmpty &&
          !_dictationSendPending) {
        _dictating = false;
      }
    });
  }

  Future<void> _finishDictation() async {
    if (_busy || !_dictating || _dictationSendPending) return;
    setState(() => _dictationSendPending = true);
    try {
      await _dictation.stop();
      if (!mounted || !_dictationSendPending) return;
      setState(() {
        _dictationSendPending = false;
        _dictating = false;
      });
      // No recognized speech must not accidentally send the previous draft.
      if (_dictation.text.trim().isEmpty) return;
      final draft = [
        _draftBeforeDictation,
        _dictation.text.trim(),
      ].where((s) => s.isNotEmpty).join(' ');
      _input.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      await _send();
    } finally {
      if (mounted) setState(() => _dictationSendPending = false);
    }
  }

  Future<void> _cancelDictation() async {
    setState(() => _dictating = false);
    await _dictation.cancel();
    if (!mounted) return;
    _input.value = TextEditingValue(
      text: _draftBeforeDictation,
      selection: TextSelection.collapsed(offset: _draftBeforeDictation.length),
    );
  }

  void _refreshVoice() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousText = {
      for (final m in oldWidget.messages)
        if (!m.isUser && m.turnId != null) m.turnId: m.text,
    };
    for (final message in widget.messages) {
      if (!message.isUser &&
          message.animateReply &&
          message.turnId != null &&
          previousText[message.turnId] != message.text) {
        _typingTurns.add(message.turnId!);
      }
    }
    _scheduleVisible();
    if (oldWidget.locationRevision != widget.locationRevision ||
        oldWidget.anchorTurnId != widget.anchorTurnId ||
        oldWidget.anchorMaterialId != widget.anchorMaterialId ||
        _anchorPending) {
      if (widget.anchorTurnId != null) {
        _scrollToAnchor();
      } else {
        ++_anchorRequest;
        _highlightTimer?.cancel();
        _focusPulse.stop();
        _highlightedTurn = null;
        _locatingAnchor = _anchorPending = false;
      }
    } else if (!_locatingAnchor &&
        _highlightedTurn == null &&
        (!_scroll.hasClients || _scroll.offset < 80) &&
        (oldWidget.messages.length != widget.messages.length ||
            oldWidget.messages.lastOrNull?.text !=
                widget.messages.lastOrNull?.text ||
            oldWidget.messages.map((m) => m.text).join() !=
                widget.messages.map((m) => m.text).join())) {
      _scrollToLatest();
    }
  }

  Future<void> _startRecording() async {
    if (_busy) return;
    _focus.unfocus();
    await _stopPlayback();
    if (!mounted) return;
    setState(() {
      _error = null;
      _recordingPreview = false;
    });
    if (widget.useSystemDictation) {
      _draftBeforeDictation = _input.text;
      setState(() => _dictating = true);
      await _dictation.start();
      return;
    }
    await _voice.start();
  }

  Future<void> _cancelRecording() async {
    if (_recordingPreview) {
      setState(() => _recordingPreview = false);
      return;
    }
    await _voice.cancel();
  }

  Future<void> _saveRecording() async {
    if (_busy) return;
    if (_recordingPreview) {
      setState(() => _recordingPreview = false);
      return;
    }
    final clip = await _voice.finish();
    if (!mounted || clip == null) return;
    setState(() {
      _sendingRecording = true;
      _error = null;
    });
    try {
      // Browser blob URLs are scoped to this page lifetime and are never
      // persisted as if they were durable native files.
      _voiceSave = widget.onVoiceRecorded == null
          ? Future.value(true)
          : widget.onVoiceRecorded!(clip);
      final saved = await _voiceSave!;
      if (!mounted) return;
      if (!saved) {
        setState(() => _error = '发送失败，录音已保留，请重试或取消。');
        return;
      }
      if (widget.onVoiceRecorded == null) {
        _ephemeralMessages.add(
          ChatMessage('', isUser: true, voice: clip, createdAt: DateTime.now()),
        );
      }
      _voice.accept();
      _scrollToLatest();
    } catch (_) {
      if (mounted) setState(() => _error = '发送失败，录音已保留，请重试或取消。');
    } finally {
      if (mounted) {
        setState(() {
          _sendingRecording = false;
          _voiceSave = null;
        });
      }
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _playback?.stop();
    } catch (_) {
      /* Keep capture available. */
    }
    if (mounted) setState(() => _playingPath = null);
  }

  Future<void> _play(VoiceClip clip) async {
    if (_busy || _recording) return;
    if (_playingPath == clip.path) {
      await _stopPlayback();
      return;
    }
    try {
      if (_playback == null) {
        _playback = widget.voicePlayback ?? DeviceVoicePlayback();
        _playbackComplete = _playback!.completed.listen((_) {
          if (mounted) setState(() => _playingPath = null);
        });
      }
      await _playback!.stop();
      await _playback!.play(clip);
      if (mounted) setState(() => _playingPath = clip.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingPath = null;
          _error = '无法播放这条本地录音，文件可能已被清理。';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_voice.recording || (_voice.busy && _voice.pending == null)) {
        unawaited(_voice.cancel());
      }
      _dictationSendPending = false;
      if (_dictating) {
        _dictating = false;
        unawaited(_dictation.cancel());
      }
      unawaited(_stopPlayback());
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_busy || _dictating || text.isEmpty) return;
    setState(() {
      _sendingText = true;
      _error = null;
    });
    try {
      final submission = widget.onSend?.call(text) ?? true;
      final sent = submission is Future<bool> ? await submission : submission;
      if (!mounted) return;
      if (!sent) {
        setState(() => _error = widget.error == null ? '发送失败，请重试' : null);
        return;
      }
      if (widget.onSend == null) {
        _localMessages.addAll([
          ChatMessage(text, isUser: true, createdAt: DateTime.now()),
          ChatMessage(
            '谢谢你告诉我！你想先聊聊兴趣，还是一起探索这个世界？（模拟回复）',
            createdAt: DateTime.now(),
          ),
        ]);
      }
      _input.clear();
      _scrollToLatest();
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.error == null ? '发送失败，请重试' : null);
      }
    } finally {
      if (mounted) setState(() => _sendingText = false);
    }
  }

  void _scrollToLatest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.useSystemDictation) {
      _dictation.removeListener(_refreshDictation);
      if (_dictating) unawaited(_dictation.cancel());
    }
    _voice.removeListener(_refreshVoice);
    unawaited(_closeVoice());
    unawaited(_playbackComplete?.cancel());
    if (_playback != null) {
      if (widget.voicePlayback == null) {
        unawaited(_playback!.dispose());
      } else {
        unawaited(_playback!.stop());
      }
    }
    for (final message in _ephemeralMessages) {
      final clip = message.voice;
      if (clip != null) {
        unawaited(deleteVoiceFile(clip.path).catchError((_) {}));
      }
    }
    _highlightTimer?.cancel();
    _focusPulse.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.removeListener(_scheduleVisible);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _closeVoice() async {
    try {
      if (await _voiceSave == true) _voice.accept();
    } catch (_) {
      /* Uncommitted drafts are removed below. */
    }
    if (widget.voiceCapture == null) {
      _voice.dispose();
    } else {
      await _voice.cancel();
    }
  }

  Widget _header() => Row(
    children: [
      if (widget.returningUser)
        IconButton(
          tooltip: '返回',
          onPressed: _busy && !widget.lockComposer ? null : widget.onExit,
          icon: chatSvg('back', width: 24, height: 24),
        ),
      Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
        decoration: BoxDecoration(
          color: const Color(0x62000000),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/chat/avatar.png',
                width: 28,
                height: 28,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              widget.name,
              style: const TextStyle(
                inherit: false,
                textBaseline: TextBaseline.alphabetic,
                fontFamily: 'PingFang SC',
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      const Spacer(),
      if (!widget.returningUser)
        TextButton(
          onPressed: _busy && !widget.lockComposer ? null : widget.onExit,
          style: TextButton.styleFrom(
            overlayColor: Colors.transparent,
            foregroundColor: const Color(0xD9FFFFFF),
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            widget.exitLabel,
            style: const TextStyle(
              inherit: false,
              textBaseline: TextBaseline.alphabetic,
              fontFamily: 'PingFang SC',
              fontSize: 14,
            ),
          ),
        ),
    ],
  );

  Widget _transcript({double bottomPadding = 0}) {
    final entries = _entries;
    final messages = entries.map((entry) => entry.message).toList();
    final thinkingGap = messages.lastOrNull?.isThinking == true ? 20.0 : 0.0;
    DateTime? previous;
    final timestamps = <int, String>{};
    for (var i = 0; i < messages.length; i++) {
      final current = messages[i].createdAt;
      if (showChatTime(previous, current)) {
        timestamps[i] = formatChatTime(current!);
      }
      if (current != null) previous = current;
    }
    final transcript = SingleChildScrollView(
      key: const ValueKey('chat-transcript'),
      physics: const ClampingScrollPhysics(),
      controller: _scroll,
      reverse: true,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + thinkingGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onLoadOlderMessages != null)
            TextButton(
              onPressed: widget.loadingOlderMessages
                  ? null
                  : widget.onLoadOlderMessages,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(widget.loadingOlderMessages ? '加载中…' : '加载更早消息'),
            ),
          if (widget.timeLabel != null) _timestamp(widget.timeLabel!),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(57),
            ),
            child: const Text(
              '所有内容均由 AI 生成，均为虚构内容。',
              textAlign: TextAlign.center,
              style: TextStyle(
                inherit: false,
                textBaseline: TextBaseline.alphabetic,
                fontFamily: 'PingFang SC',
                fontSize: 12,
                height: 1.5,
                color: Color(0xCCFFFFFF),
              ),
            ),
          ),
          const SizedBox(height: 21),
          if (widget.showWelcome)
            SizedBox(
              width: double.infinity,
              child: ChatGreeting(name: widget.name),
            ),
          for (var i = 0; i < messages.length; i++) ...[
            SizedBox(height: i == 0 ? 24 : 16),
            if (timestamps[i] != null) _timestamp(timestamps[i]!),
            if (messages[i].voice case final clip?)
              _voiceBubble(clip)
            else
              _messageBubble(entries[i]),
          ],
        ],
      ),
    );
    return _messages.length < 3
        ? transcript
        : ListenableBuilder(
            listenable: _scroll,
            child: transcript,
            builder: (_, child) {
              final showingHistoryAction =
                  widget.onLoadOlderMessages != null &&
                  _scroll.hasClients &&
                  _scroll.position.hasContentDimensions &&
                  _scroll.position.extentAfter < 48;
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _locatingAnchor ||
                            _highlightedTurn != null ||
                            showingHistoryAction
                        ? Colors.white
                        : Colors.transparent,
                    Colors.white,
                    Colors.white,
                  ],
                  stops: [0, (161 / bounds.height).clamp(0, 1), 1],
                ).createShader(bounds),
                child: child,
              );
            },
          );
  }

  Widget _timestamp(String label) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Center(
      child: Text(
        label,
        key: ValueKey('chat-time-$label'),
        style: const TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 12,
          color: Color(0xCCFFFFFF),
          height: 1.5,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    ),
  );

  Widget _locationNotice() => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) || !widget.animate
        ? Duration.zero
        : const Duration(milliseconds: 280),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -.25), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    ),
    child: _highlightedTurn == null
        ? const SizedBox.shrink()
        : Center(
            key: ValueKey('location-$_anchorRequest'),
            child: Container(
              key: const ValueKey('chat-location-notice'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF2351D55),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFFFDF84)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 16,
                    color: Color(0xFFFFDF84),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '已定位到这条发现',
                    style: TextStyle(
                      color: Color(0xFFFFDF84),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
  );

  void _scheduleVisible() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted ||
        _locatingAnchor ||
        !_scroll.hasClients ||
        widget.onDiscoveryVisible == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final viewport = _scroll.position.context.notificationContext
        ?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    final renderedTurns = {
      for (final entry in _entries)
        for (final message in entry.messages)
          if (message.turnId != null) message.turnId: entry.message.turnId,
    };
    for (final message in widget.messages) {
      final task = message.referenceTaskId;
      if (task == null ||
          message.cards.isEmpty ||
          _reportedTasks.contains(task)) {
        continue;
      }
      final renderedId = renderedTurns[message.turnId] ?? message.turnId;
      final carousel = _discoveryKeys[renderedId]?.currentState;
      if (carousel != null &&
          carousel.selectedCard?['_chatTurnId'] != message.turnId) {
        continue;
      }
      final box = _turnKeys[renderedId]?.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          bounds.overlaps(box.localToGlobal(Offset.zero) & box.size)) {
        _reportedTasks.add(task);
        widget.onDiscoveryVisible!(task);
      }
    }
  });

  void _scrollToAnchor() {
    _focus.unfocus();
    _highlightTimer?.cancel();
    _focusPulse.stop();
    _focusPulse.value = 0;
    final request = ++_anchorRequest;
    _highlightedTurn = null;
    _locatingAnchor = true;
    _anchorPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || request != _anchorRequest) return;
      final id = widget.anchorTurnId;
      final renderedId = _renderedTurnId(id);
      final carousel = _discoveryKeys[renderedId]?.currentState;
      if (carousel != null) {
        final cards = widget.messages
            .where((m) => m.turnId == id)
            .firstOrNull
            ?.cards;
        if (widget.anchorMaterialId != null &&
            cards?.any(
                  (card) => card['materialId'] == widget.anchorMaterialId,
                ) !=
                true) {
          _anchorPending = true;
          return;
        }
      }
      if (!mounted || request != _anchorRequest) return;
      final target = _turnKeys[renderedId]?.currentContext;
      if (target == null || !target.mounted || !_scroll.hasClients) {
        _anchorPending = true;
        return;
      }
      final duration =
          !widget.animate || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 550);
      final message = widget.messages.where((m) => m.turnId == id).firstOrNull;
      final title = message == null ? null : _anchorTitle(message);
      final paragraph = _textKeys[id]?.currentContext?.findRenderObject();
      final start = title == null ? -1 : message!.text.indexOf(title);
      if (paragraph is RenderParagraph && start >= 0) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + title!.length),
        );
        if (boxes.isNotEmpty) {
          final offset = RenderAbstractViewport.of(paragraph)
              .getOffsetToReveal(paragraph, 0.45, rect: boxes.first.toRect())
              .offset;
          await _scroll.animateTo(
            offset.clamp(
              _scroll.position.minScrollExtent,
              _scroll.position.maxScrollExtent,
            ),
            duration: duration == Duration.zero
                ? const Duration(milliseconds: 1)
                : duration,
            curve: Curves.easeInOutCubic,
          );
        } else {
          await Scrollable.ensureVisible(
            target,
            alignment: 0.45,
            duration: duration,
          );
        }
      } else {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.45,
          duration: duration,
        );
      }
      if (!mounted || request != _anchorRequest) return;
      // Bring the row on screen first, then visibly slide to the chosen card.
      final visibleCarousel = _discoveryKeys[renderedId]?.currentState;
      if (visibleCarousel != null) {
        final selected = await visibleCarousel.revealMaterial(
          widget.anchorMaterialId,
          turnId: id,
        );
        if (!mounted || request != _anchorRequest) return;
        if (!selected) {
          _locatingAnchor = false;
          return;
        }
      }
      setState(() {
        _locatingAnchor = false;
        _highlightedTurn = id;
      });
      _scheduleVisible();
      if (!MediaQuery.disableAnimationsOf(context) && widget.animate) {
        _focusPulse.forward(from: 0);
      }
      widget.onAnchorVisible?.call();
      if (!mounted || request != _anchorRequest) return;
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && request == _anchorRequest) {
          setState(() => _highlightedTurn = null);
        }
      });
    });
  }

  String? _anchorTitle(ChatMessage message) {
    final card = message.cards
        .where((c) => c['materialId'] == widget.anchorMaterialId)
        .firstOrNull;
    final title = card?['title'];
    return title is String && title.isNotEmpty ? title : null;
  }

  Widget _messageBubble(ChatTranscriptEntry entry) {
    final message = entry.message;
    final highlighted = entry.containsTurn(_highlightedTurn);
    final textKey = message.turnId == null
        ? null
        : _textKeys.putIfAbsent(message.turnId!, GlobalKey.new);
    final bubble = message.hasStructuredDiscoveries
        ? ChatDiscoveryCarousel(
            key: message.turnId == null
                ? null
                : _discoveryKeys.putIfAbsent(
                    message.turnId!,
                    GlobalKey<ChatDiscoveryCarouselState>.new,
                  ),
            cards: entry.cards,
            onPageChanged: _scheduleVisible,
            highlightedTurnId: highlighted ? _highlightedTurn : null,
            animate: widget.animate,
            focusAnimation: _focusPulse,
            highlightedMaterialId: highlighted ? widget.anchorMaterialId : null,
          )
        : message.isUser
        ? ChatBubble(text: message.text, isUser: true)
        : message.isThinking
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              liveRegion: true,
              child: const ChatGlass(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFD6CBFF),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(dimension: 6),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '正在思考…',
                          style: TextStyle(
                            fontFamily: 'PingFang SC',
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : ChatTypewriter(
            text: message.text,
            animate:
                widget.animate &&
                !highlighted &&
                _typingTurns.contains(message.turnId),
            textKey: textKey,
            highlightText: highlighted ? _anchorTitle(message) : null,
          );
    return KeyedSubtree(
      key: switch (message) {
        ChatMessage(:final turnId?) =>
          _turnKeys.putIfAbsent(turnId, GlobalKey.new),
        ChatMessage(:final clientMessageId?) => ValueKey(clientMessageId),
        _ => null,
      },
      child: bubble,
    );
  }

  Widget _voiceBubble(VoiceClip clip) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 269),
      child: Material(
        color: const Color(0xFFD8CCFF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: InkWell(
          onTap: () => _play(clip),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _playingPath == clip.path
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  semanticLabel: _playingPath == clip.path ? '停止播放' : '播放录音',
                  color: const Color(0xFF51397B),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '语音 ${math.max(1, clip.duration.inSeconds)}秒 · ${clip.ephemeral ? '本次会话' : '仅本机'}',
                    style: const TextStyle(
                      inherit: false,
                      textBaseline: TextBaseline.alphabetic,
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _composer() => TextFieldTapRegion(
    child: Row(
      children: [
        Expanded(
          child: ChatGlass(
            child: SizedBox(
              height: 49,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      readOnly: widget.lockComposer,
                      canRequestFocus: !widget.lockComposer,
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => _busy ? oldValue : newValue,
                        ),
                      ],
                      textInputAction: TextInputAction.send,
                      onEditingComplete: () {},
                      onTapOutside: (_) => _focus.unfocus(),
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => setState(() {}),
                      cursorColor: const Color(0xFFA64BFB),
                      style: const TextStyle(
                        inherit: false,
                        textBaseline: TextBaseline.alphabetic,
                        fontFamily: 'PingFang SC',
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: '输入你想说的话…',
                        hintStyle: TextStyle(
                          inherit: false,
                          textBaseline: TextBaseline.alphabetic,
                          color: Color(0xFFB1B0B2),
                          fontFamily: 'PingFang SC',
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.lockComposer || _sendingText
                        ? null
                        : _busy
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : _input.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空输入',
                            onPressed: () {
                              setState(_input.clear);
                              _focus.requestFocus();
                            },
                            padding: EdgeInsets.zero,
                            icon: chatSvg('clear', width: 31, height: 31),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        ChatGlass(
          child: SizedBox(
            width: 53,
            height: 49,
            child: IconButton(
              tooltip: '开始录音',
              padding: EdgeInsets.zero,
              alignment: Alignment.center,
              iconSize: 28,
              onPressed: _busy ? null : _startRecording,
              icon: chatSvg('mic', width: 28, height: 28),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _recordingBar() => Center(
    child: SizedBox(
      width: 236,
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 36,
            height: 48,
            child: OverflowBox(
              minWidth: 44,
              maxWidth: 44,
              child: IconButton(
                tooltip: '取消录音',
                padding: EdgeInsets.zero,
                onPressed: _busy
                    ? null
                    : (_dictating ? _cancelDictation : _cancelRecording),
                icon: chatSvg('record_cancel', width: 36, height: 36),
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 25,
                child: Center(
                  child: Transform.scale(
                    scaleY:
                        _recordingPreview ||
                            !widget.animate ||
                            MediaQuery.disableAnimationsOf(context)
                        ? 1
                        : 0.25 +
                              (_dictating ? _dictation.level : _voice.level) *
                                  0.75,
                    child: chatSvg('waveform', width: 41.56, height: 23),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      inherit: false,
                      textBaseline: TextBaseline.alphabetic,
                      fontFamily: 'Newsreader',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: IconButton(
              tooltip: _dictating || _dictationSendPending ? '发送' : '完成录音',
              padding: EdgeInsets.zero,
              onPressed: _busy
                  ? null
                  : (_dictating ? _finishDictation : _saveRecording),
              icon: _sendingRecording || _dictationSendPending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const ChatSendIcon(),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
    ),
    child: PopScope(
      canPop: !_busy || widget.lockComposer,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: ChatBackground()),
            SafeArea(
              top: false,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final media = MediaQuery.of(context);
                  final headerTop =
                      math.max(
                        media.padding.top,
                        constraints.maxHeight >= 600 ? 44.0 : 0.0,
                      ) +
                      9;
                  final bottomSafeArea = math.max(media.viewPadding.bottom, 34.0);
                  final footerBottom =
                      math.max(media.viewInsets.bottom, bottomSafeArea) + 8;
                  final footerTop = constraints.maxHeight - footerBottom - 49;
                  final bannerTop = headerTop + 52;
                  final showBanner =
                      !widget.returningUser && footerTop - 68 > headerTop + 124;
                  final messageTop = headerTop + (showBanner ? 108 : 52);
                  // The floating explore button is an overlay, not the list
                  // boundary. Messages remain visible beside and below it,
                  // all the way down to the composer.
                  final messageBottom = math.max(messageTop + 1, footerTop - 9);
                  final welcomeGap = math.min(
                    68.0,
                    math.max(8.0, (footerTop - 64 - messageTop) * 0.25),
                  );
                  final welcomePadding = _messages.isEmpty && showBanner
                      ? math.max(
                          0.0,
                          messageBottom - (footerTop - 64 - welcomeGap),
                        )
                      : 0.0;
                  final error = widget.error ?? _error ?? _voice.error;
                  return Stack(
                    children: [
                      Positioned(
                        top: headerTop,
                        left: widget.returningUser ? 4 : 16,
                        right: 8,
                        height: 44,
                        child: _header(),
                      ),
                      Positioned(
                        top: messageTop,
                        left: 0,
                        right: 0,
                        height: math.max(1, messageBottom - messageTop),
                        child: _transcript(bottomPadding: welcomePadding),
                      ),
                      Positioned(
                        top: messageTop + 4,
                        left: 24,
                        right: 24,
                        child: IgnorePointer(child: _locationNotice()),
                      ),
                      if (showBanner)
                        Positioned(
                          left: 0,
                          top: (bannerTop + _exploreBannerOffset.dy).clamp(
                            headerTop + 52,
                            math.max(headerTop + 52, footerTop - 49),
                          ),
                          child: ChatExploreBanner(
                            initiallyCollapsed: _exploreBannerCollapsed,
                            onCollapsedChanged: (value) =>
                                setState(() => _exploreBannerCollapsed = value),
                            onDragUpdate: (delta) => setState(() {
                              final next = _exploreBannerOffset + delta;
                              _exploreBannerOffset = Offset(
                                0,
                                next.dy.clamp(
                                  headerTop + 52 - bannerTop,
                                  math.max(headerTop + 52, footerTop - 49) -
                                      bannerTop,
                                ),
                              );
                            }),
                            onPressed: _busy ? null : widget.onExplore,
                          ),
                        ),
                      if (error != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: footerBottom + 57,
                          child: Text(
                            error,
                            style: const TextStyle(
                              inherit: false,
                              textBaseline: TextBaseline.alphabetic,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: footerBottom,
                        height: 50,
                        child: _dictating || _dictationSendPending || _recording
                            ? _recordingBar()
                            : _composer(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
