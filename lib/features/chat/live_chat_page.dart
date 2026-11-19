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
  }) : assert(controller == null || createController == null);
  final VoidCallback onExit, onExplore;
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
      messages: _chat?.messages ?? const [],
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
        return _chat!.submitText(text);
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
                        Text(
                          _controllerLoadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _retryController,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
