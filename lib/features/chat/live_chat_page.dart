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
    this.taskId,
    this.materialId,
    this.onDiscoveryVisible,
  });
  final VoidCallback onExit, onExplore;
  final AccountService accountService;
  final bool returningUser, startRecordingOnOpen;
  final String initialDraft;
  final String? error;
  final bool busy;
  final ChatController? controller;
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
        if (widget.taskId != null) {
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
      final profile = await const StartupProfileStore().read();
      if (!mounted) return;
      _chat = ChatController(
        ChatService.authenticated(widget.accountService),
        displayName:
            profile['name'] as String? ??
            widget.accountService.session?.nick ??
            '',
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
    } catch (_) {
      if (mounted) setState(() => _error = '无法初始化聊天，请退出后重试');
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
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
  Widget build(BuildContext context) => ChatPage(
    returningUser: widget.returningUser,
    messages: _chat?.messages ?? const [],
    busy:
        widget.busy || (_chat?.sending ?? false) || (_chat?.locating ?? false),
    error: widget.error ?? _error ?? _chat?.error,
    showWelcome: false,
    anchorTurnId: _chat?.anchorTurnId,
    anchorMaterialId: _chat?.referenceMaterialId,
    locationRevision: _chat?.locationRevision ?? 0,
    onAnchorVisible: () {
      final task = _chat?.referenceTaskId;
      if (task != null) unawaited(widget.onDiscoveryVisible?.call(task));
    },
    onDiscoveryVisible: (task) =>
        unawaited(widget.onDiscoveryVisible?.call(task)),
    initialDraft: widget.initialDraft,
    startRecordingOnOpen: widget.startRecordingOnOpen,
    onSend: (text) async {
      if (_chat == null || _chat!.loading) {
        setState(() => _error = '正在连接聊天，请稍后发送');
        return false;
      }
      setState(() => _error = null);
      return _chat!.send(text);
    },
    useSystemDictation: true,
    onExit: widget.onExit,
    onExplore: widget.onExplore,
  );
}
