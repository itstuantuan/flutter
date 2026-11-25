import '../../core/localization/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/account_service.dart';
import '../auth/auth_gate.dart';
import '../auth/startup_profile_store.dart';
import 'chat_controller.dart';
import 'chat_page.dart';
import 'chat_service.dart';

/// Own the stream for exactly the lifetime of the visible conversation.
class LiveChatPage extends StatefulWidget {
  const LiveChatPage({
    super.key,
    required this.onExit,
    required this.onExplore,
    required this.accountService,
    this.returningUser = true,
    this.initialDraft = '',
    this.error,
    this.busy = false,
    this.startRecordingOnOpen = false,
    this.controller,
    this.createController,
    this.taskId,
    this.materialId,
    this.onDiscoveryVisible,
    this.discoveryCards = const [],
    this.referenceCard,
  }) : assert(controller == null || createController == null);
  final VoidCallback onExit, onExplore;
  final List<Map<String, dynamic>> discoveryCards;
  final Map<String, dynamic>? referenceCard;
  final AccountService accountService;
  final bool returningUser, startRecordingOnOpen;
  final String initialDraft;
  final String? error;
  final bool busy;
  final ChatController? controller;
  final Future<ChatController> Function()? createController;
  final String? taskId, materialId;
  final Future<void> Function(String taskId)? onDiscoveryVisible;

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage>
    with WidgetsBindingObserver {
  ChatController? _chat;
  bool _foreground = true;
  String? _error;
  late Map<String, dynamic>? _reference = widget.referenceCard;
  String? _controllerLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (widget.controller != null) {
        _chat = widget.controller!..addListener(_refresh);
        _chat!.clearLocation();
        if (_reference != null) {
          // This controller may also be observed by the underlying home route.
          // Notify only after mounting the chat route has finished.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _chat!.referenceDiscovery(_reference);
          });
        }
        if (widget.taskId != null && _reference == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(
                _chat!.locate(widget.taskId!, materialId: widget.materialId),
              );
            }
          });
        }
        setState(() {});
        return;
      }
      final createController = widget.createController;
      if (createController != null) {
        final controller = await createController();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _chat = controller..addListener(_refresh);
        setState(() {});
        if (_foreground) unawaited(_chat!.start());
        return;
      }
      final session = widget.accountService.session;
      if (session == null) throw StateError('请先登录');
      final profile = await const StartupProfileStore().readUser(session.uid);
      if (!mounted || !identical(widget.accountService.session, session)) {
        return;
      }
      _chat = ChatController(
        ChatService.forSession(session),
        displayName: profile['name'] as String? ?? session.nick,
        onUnauthorized: () async {
          await widget.accountService.logout();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => AuthGate(service: widget.accountService),
            ),
            (_) => false,
          );
        },
      )..addListener(_refresh);
      setState(() {});
      if (_foreground) unawaited(_chat!.start());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (widget.createController != null) {
          _controllerLoadError = e is ChatException
              ? e.message
              : '暂时无法加载对话，请重试。';
        } else {
          _error = '无法初始化聊天，请退出后重试';
        }
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _retryController() {
    if (_controllerLoadError == null) return;
    setState(() => _controllerLoadError = null);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.controller != null) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(_chat?.start());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _chat?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat?.removeListener(_refresh);
    if (widget.controller == null) {
      _chat?.dispose();
    } else {
      _chat?.clearLocation();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitingForController =
        widget.createController != null && _chat == null;
    final chat = ChatPage(
      returningUser: widget.returningUser,
      referenceCard: _reference,
      discoveryService: _chat?.service,
      onReferenceChanged: (card) {
        setState(() => _reference = card);
        _chat?.referenceDiscovery(card);
      },
      messages: _chat?.messages ?? const [],
      discoveryCards: [...?_chat?.discoveryCards, ...widget.discoveryCards],
      discoverySnapshotReady: _chat != null && !_chat!.loading,
      busy:
          widget.busy ||
          (_chat?.sending ?? false) ||
          (_chat?.locating ?? false),
      error: widget.error ?? _error ?? _chat?.error,
      showWelcome: false,
      lockComposer: waitingForController,
      anchorTurnId: _chat?.anchorTurnId,
      anchorMaterialId: _chat?.referenceMaterialId,
      locationRevision: _chat?.locationRevision ?? 0,
      onLoadOlderMessages: _chat?.hasOlderMessages == true
          ? () => unawaited(_chat!.loadOlderMessages())
          : null,
      loadingOlderMessages: _chat?.loadingOlderMessages ?? false,
      onAnchorVisible: () {
        final task = _chat?.referenceTaskId;
        if (task != null) unawaited(widget.onDiscoveryVisible?.call(task));
      },
      onDiscoveryVisible: (task) =>
          unawaited(widget.onDiscoveryVisible?.call(task)),
      initialDraft: widget.initialDraft,
      startRecordingOnOpen: widget.startRecordingOnOpen,
      onSend: (text) {
        if (_chat == null || _chat!.loading) {
          setState(() => _error = '正在连接聊天，请稍后发送');
          return false;
        }
        setState(() => _error = null);
        // Quoted drafts clear only after the server accepts the message.
        return _reference == null ? _chat!.submitText(text) : _chat!.send(text);
      },
      useSystemDictation: true,
      onExit: widget.onExit,
      onExplore: widget.onExplore,
    );
    if (widget.createController == null) return chat;
    return Stack(
      fit: StackFit.expand,
      children: [
        chat,
        if (waitingForController)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _controllerLoadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          _controllerLoadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _retryController,
                          child: const AppText('重试'),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
