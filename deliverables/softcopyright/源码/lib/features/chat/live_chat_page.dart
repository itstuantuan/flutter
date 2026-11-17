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
  });
  final VoidCallback onExit, onExplore;
  final AccountService accountService;
  final bool returningUser, startRecordingOnOpen;
  final String initialDraft;
  final String? error;
  final bool busy;

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
    _chat?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatPage(
    name: 'Tony',
    returningUser: widget.returningUser,
    messages: _chat?.messages ?? const [],
    busy: widget.busy || (_chat?.sending ?? false),
    error: widget.error ?? _error ?? _chat?.error,
    showWelcome: false,
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
    onExit: widget.onExit,
    onExplore: widget.onExplore,
  );
}
