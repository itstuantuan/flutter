import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'chat_message.dart';
import 'chat_service.dart';

class ChatController extends ChangeNotifier {
  ChatController(
    this.service, {
    required this.displayName,
    this.onUnauthorized,
  });
  final ChatService service;
  final String displayName;
  final Future<void> Function()? onUnauthorized;
  final _turns = <int, Map<String, dynamic>>{};
  String? _sessionId, error;
  String? _pendingId, _pendingText;
  bool loading = true, sending = false, _disposed = false, _active = false;
  bool _authFailed = false;
  int _generation = 0, _attempt = 0;
  CancelToken? _connection, _sendCancel;
  Timer? _reconnect;

  List<ChatMessage> get messages {
    final turns = _turns.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return [
      for (final turn in turns)
        if (turn['messageType'] != 'explore_task') ...[
          if ((turn['userText'] as String? ?? '').isNotEmpty &&
              !{'welcome', 'discovery'}.contains(turn['messageType']))
            ChatMessage(turn['userText'] as String, isUser: true),
          if ((turn['assistantText'] as String? ?? '').isNotEmpty)
            ChatMessage(turn['assistantText'] as String),
          if (turn['status'] == 'queued' || turn['status'] == 'processing')
            ChatMessage(
              turn['status'] == 'queued' ? 'Tony 正在等待回复…' : 'Tony 正在回复…',
            ),
          if (turn['status'] == 'failed')
            const ChatMessage('这次回复未完成，请重新发送消息再试。'),
        ],
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void merge(Map<String, dynamic> snapshot) {
    final turns = snapshot['turns'];
    if (turns is! List) throw const ChatException('聊天快照格式错误');
    for (final raw in turns) {
      final turn = Map<String, dynamic>.from(raw as Map);
      final id = turn['id'] as int;
      final old = _turns[id];
      if (old == null ||
          (turn['updateTime'] as int? ?? 0) >= (old['updateTime'] as int? ?? 0)) {
        _turns[id] = turn;
      }
    }
    _notify();
  }

  Future<void> start() async {
    if (_disposed || _active || _authFailed) return;
    _active = true;
    final generation = ++_generation;
    final cancel = _connection = CancelToken();
    try {
      if (_sessionId == null) {
        var state = await service.request('/me', cancelToken: cancel);
        if (state['initialized'] != true || state['sessionId'] == null) {
          state = await service.request(
            '/me/bootstrap',
            method: 'POST',
            data: {
              if (displayName.trim().isNotEmpty)
                'displayName': displayName.trim(),
              'languageTag': 'zh-CN',
              'timeZone': 'Asia/Shanghai',
              'soundEnabled': true,
            },
            cancelToken: cancel,
          );
        }
        _sessionId = state['sessionId'] as String?;
        if (_sessionId == null || _sessionId!.isEmpty) {
          throw const ChatException('聊天会话尚未初始化');
        }
      }
      await service.request('/home', cancelToken: cancel);
      final snapshot = await service.request(
        '/sessions/${Uri.encodeComponent(_sessionId!)}/messages',
        cancelToken: cancel,
      );
      if (generation != _generation) return;
      merge(snapshot);
      loading = false;
      error = null;
      _notify();
      await for (final event in service.subscribe(_sessionId!, cancel)) {
        if (generation != _generation) return;
        if (event.type == 'stream_error') {
          throw const ChatException('聊天连接中断，正在重连');
        }
        if (event.type == 'snapshot') {
          merge(Map<String, dynamic>.from(jsonDecode(event.data) as Map));
          _attempt = 0;
          error = null;
          _notify();
        }
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[Chat] stream failure ${e.runtimeType}\n$stack');
      if (generation != _generation) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      await _handleError(e);
    } finally {
      if (generation == _generation && !_disposed) {
        _active = false;
        loading = false;
        _notify();
        if (!_authFailed) {
          final seconds = [1, 2, 4, 8, 10][min(_attempt++, 4)];
          _reconnect = Timer(Duration(seconds: seconds), start);
        }
      }
    }
  }

  Future<void> _handleError(Object e) async {
    if (e is DioException && e.response?.statusCode == 401) {
      _authFailed = true;
      error = '登录已过期，请重新登录';
      _notify();
      await onUnauthorized?.call();
    } else {
      error = e is DioException
          ? e.userMessage
          : e is ChatException
          ? e.message
          : '聊天暂时不可用，请稍后重试';
      _notify();
    }
  }

  Future<bool> send(String text) async {
    text = text.trim();
    if (sending || _sessionId == null || _authFailed || text.isEmpty) {
      return false;
    }
    if (text.runes.length > 4000) {
      error = '单条消息最多 4000 字';
      _notify();
      return false;
    }
    // Keep the operation ID after an ambiguous network failure.
    if (_pendingText != text) {
      _pendingText = text;
      final random = Random.secure();
      _pendingId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    sending = true;
    error = null;
    _notify();
    final cancel = _sendCancel = CancelToken();
    try {
      final turn = await service.request(
        '/sessions/${Uri.encodeComponent(_sessionId!)}/messages',
        method: 'POST',
        data: {
          'clientMessageId': _pendingId,
          'message': text,
          'attachmentIds': <String>[],
        },
        cancelToken: cancel,
      );
      if (_disposed) return false;
      merge({
        'turns': [turn],
      });
      _pendingText = null;
      _pendingId = null;
      return true;
    } catch (e) {
      if (!_disposed) await _handleError(e);
      return false;
    } finally {
      sending = false;
      _notify();
    }
  }

  void pause() {
    ++_generation;
    _active = false;
    _reconnect?.cancel();
    _connection?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    _sendCancel?.cancel();
    super.dispose();
  }
}
