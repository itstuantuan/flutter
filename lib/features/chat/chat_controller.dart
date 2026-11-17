import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'chat_message.dart';
import 'chat_service.dart';

String newOperationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class ChatController extends ChangeNotifier {
  ChatController(
    this.service, {
    required this.displayName,
    this.onUnauthorized,
    this.onHome,
    this.loadHome,
    this.onCompletion,
  });
  final ChatService service;
  final Future<Map<String, dynamic>> Function()? loadHome;
  final String displayName;
  final Future<void> Function()? onUnauthorized;
  final void Function(Map<String, dynamic>)? onHome, onCompletion;
  final _turns = <int, Map<String, dynamic>>{};
  final _liveReplies = <int>{};
  String? _sessionId, error;
  Future<String>? _initializing;
  String? _pendingId, _pendingFingerprint;
  bool loading = true, sending = false, locating = false;
  bool _disposed = false, _active = false, _authFailed = false;
  int _generation = 0, _attempt = 0;
  CancelToken? _connection, _sendCancel, _locateCancel;
  Timer? _reconnect;
  int? anchorTurnId;
  int locationRevision = 0;
  String? referenceTaskId, referenceMaterialId;
  String? get sessionId => _sessionId;
  bool get unauthorized => _authFailed;

  List<ChatMessage> get messages {
    final turns = _turns.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return [
      for (final turn in turns)
        if (turn['messageType'] != 'explore_task') ...[
          if (((turn['userText'] as String? ?? '').isNotEmpty ||
                  (turn['attachmentIds'] as List? ?? []).isNotEmpty) &&
              !{'welcome', 'discovery'}.contains(turn['messageType']))
            ChatMessage(
              (turn['userText'] as String? ?? '').isNotEmpty
                  ? turn['userText'] as String
                  : '语音消息',
              isUser: true,
              createdAt: _createdAt(turn),
            ),
          if ((turn['assistantText'] as String? ?? '').isNotEmpty ||
              _cards(turn).isNotEmpty)
            ChatMessage(
              turn['assistantText'] as String? ?? '',
              turnId: turn['id'] as int,
              referenceTaskId: turn['referenceTaskId'] as String?,
              cards: _cards(turn),
              createdAt: _createdAt(turn),
              animateReply: _liveReplies.contains(turn['id']),
            ),
          if (turn['status'] == 'failed')
            ChatMessage(
              '这次回复未完成，请重新发送消息再试。${_failureCode(turn)}',
              createdAt: _createdAt(turn),
              turnId: (turn['assistantText'] as String? ?? '').isEmpty
                  ? turn['id'] as int
                  : null,
            ),
        ],
    ];
  }

  DateTime? _createdAt(Map<String, dynamic> turn) {
    final value = turn['createTime'];
    return value is int && value > 0
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : null;
  }

  List<Map<String, dynamic>> _cards(Map<String, dynamic> turn) {
    // Only render the backend's published discovery; never create one from an event.
    if (turn['messageType'] != 'discovery' &&
        turn['messageType'] != 'explore') {
      return const [];
    }
    if (turn['status'] != 'completed') return const [];
    final raw = (turn['exploration'] as Map?)?['cards'];
    if (raw is! List) return const [];
    return raw.map((card) => Map<String, dynamic>.from(card as Map)).toList();
  }

  String _failureCode(Map<String, dynamic> turn) {
    final code = turn['errorCode'];
    return code is String && RegExp(r'^[A-Z0-9_]{1,80}$').hasMatch(code)
        ? '（$code）'
        : '';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void merge(Map<String, dynamic> snapshot, {bool live = false}) {
    final turns = snapshot['turns'];
    if (turns is! List) throw const ChatException('聊天快照格式错误');
    for (final raw in turns) {
      final turn = Map<String, dynamic>.from(raw as Map);
      final id = turn['id'] as int;
      final old = _turns[id];
      if (old == null ||
          (turn['updateTime'] as int? ?? 0) >=
              (old['updateTime'] as int? ?? 0)) {
        _turns[id] = turn;
        if (live && old?['assistantText'] != turn['assistantText']) {
          _liveReplies.add(id);
        } else if (!live) {
          _liveReplies.remove(id);
        }
      }
    }
    _notify();
  }

  Future<String> initializeSession({CancelToken? cancelToken}) {
    if (_sessionId != null) return Future.value(_sessionId);
    return _initializing ??= _initializeSession(cancelToken).whenComplete(() {
      _initializing = null;
    });
  }

  Future<String> _initializeSession(CancelToken? cancel) async {
    var state = await service.request('/me', cancelToken: cancel);
    if (state['initialized'] != true || state['sessionId'] == null) {
      state = await service.request(
        '/me/bootstrap',
        method: 'POST',
        data: {
          if (displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
          'languageTag': 'zh-CN',
          'timeZone': 'Asia/Shanghai',
          'soundEnabled': true,
        },
        cancelToken: cancel,
      );
    }
    final id = state['sessionId'] as String?;
    if (id == null || id.isEmpty) throw const ChatException('聊天会话尚未初始化');
    if (!_disposed) _sessionId = id;
    return id;
  }

  Future<void> _refreshHistory(CancelToken cancel) async {
    final base = '/sessions/${Uri.encodeComponent(_sessionId!)}/messages';
    // Backfill after the last known turn before applying the latest-50 snapshot.
    // This also preserves the context loaded by locate.
    if (_turns.isNotEmpty) {
      var cursor = _turns.keys.reduce(max);
      while (!cancel.isCancelled) {
        final page = await service.request(
          '$base/after',
          query: {'after': cursor},
          cancelToken: cancel,
        );
        merge(page);
        final turns = page['turns'] as List;
        if (page['hasMore'] != true || turns.isEmpty) break;
        final next = (turns.last as Map)['id'] as int;
        if (next <= cursor) throw const ChatException('历史分页游标无效');
        cursor = next;
      }
    }
    merge(await service.request(base, cancelToken: cancel));
  }

  Future<void> start() async {
    if (_disposed || _active || _authFailed) return;
    _reconnect?.cancel();
    _active = true;
    final generation = ++_generation;
    final cancel = _connection = CancelToken();
    try {
      await initializeSession(cancelToken: cancel);
      final home =
          await (loadHome?.call() ??
              service.request('/home', cancelToken: cancel));
      if (generation != _generation) return;
      onHome?.call(home);
      await _refreshHistory(cancel);
      if (onCompletion != null) {
        final events = await service.requestList(
          '/explorations/completions',
          cancelToken: cancel,
        );
        for (final event in events) {
          onCompletion!(event);
        }
      }
      if (generation != _generation) return;
      loading = false;
      error = null;
      _notify();
      await for (final event in service.subscribe(_sessionId!, cancel)) {
        if (generation != _generation) return;
        if (event.type == 'stream_error') {
          throw const ChatException('聊天连接中断，正在重连');
        }
        if (event.type == 'snapshot') {
          merge(
            Map<String, dynamic>.from(jsonDecode(event.data) as Map),
            live: true,
          );
          _attempt = 0;
          error = null;
          _notify();
        } else if (event.type == 'exploration_completed') {
          onCompletion?.call(
            Map<String, dynamic>.from(jsonDecode(event.data) as Map),
          );
        }
      }
    } catch (e) {
      if (generation != _generation) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      await handleError(e);
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

  Future<void> handleError(Object e) async {
    if (e is DioException && e.type == DioExceptionType.cancel) return;
    if (e is DioException && e.response?.statusCode == 401) {
      if (_authFailed) return;
      _authFailed = true;
      pause();
      error = '登录已过期，请重新登录';
      _notify();
      await onUnauthorized?.call();
    } else {
      error = e is DioException
          ? e.userMessage
          : e is ChatException
          ? e.message
          : '暂时不可用，请稍后重试';
      _notify();
    }
  }

  Future<bool> locate(String taskId, {String? materialId}) async {
    _locateCancel?.cancel();
    final cancel = _locateCancel = CancelToken();
    locating = true;
    error = null;
    _notify();
    try {
      final session = await initializeSession();
      final result = await service.request(
        '/sessions/${Uri.encodeComponent(session)}/messages/locate/${Uri.encodeComponent(taskId)}',
        cancelToken: cancel,
      );
      if (_disposed || cancel.isCancelled) return false;
      final anchor = result['anchorTurnId'] as int;
      if (!(result['turns'] as List).any(
        (turn) => (turn as Map)['id'] == anchor,
      )) {
        throw const ChatException('对应发现尚未加载，请重试');
      }
      merge(result);
      anchorTurnId = anchor;
      referenceTaskId = taskId;
      referenceMaterialId = materialId;
      locationRevision++;
      return true;
    } catch (e) {
      if (!_disposed && !cancel.isCancelled) await handleError(e);
      return false;
    } finally {
      if (!cancel.isCancelled) {
        locating = false;
        _notify();
      }
    }
  }

  void clearLocation() {
    _locateCancel?.cancel();
    locating = false;
    anchorTurnId = null;
    referenceTaskId = null;
    referenceMaterialId = null;
  }

  Future<bool> send(
    String text, {
    List<String> attachmentIds = const [],
  }) async {
    text = text.trim();
    if (sending ||
        locating ||
        _sessionId == null ||
        _authFailed ||
        (text.isEmpty && attachmentIds.isEmpty)) {
      return false;
    }
    if (text.length > 4000) {
      error = '单条消息最多 4000 字';
      _notify();
      return false;
    }
    final body = <String, dynamic>{
      'message': text,
      'attachmentIds': attachmentIds,
      if (referenceTaskId != null) 'referenceTaskId': referenceTaskId,
      if (referenceMaterialId != null)
        'referenceMaterialId': referenceMaterialId,
    };
    final fingerprint = jsonEncode(body);
    if (_pendingFingerprint != fingerprint) {
      _pendingFingerprint = fingerprint;
      _pendingId = newOperationId();
    }
    sending = true;
    error = null;
    _notify();
    final cancel = _sendCancel = CancelToken();
    try {
      final turn = await service.request(
        '/sessions/${Uri.encodeComponent(_sessionId!)}/messages',
        method: 'POST',
        data: {'clientMessageId': _pendingId, ...body},
        cancelToken: cancel,
      );
      if (_disposed) return false;
      merge({
        'turns': [turn],
      }, live: true);
      _pendingFingerprint = null;
      _pendingId = null;
      return true;
    } catch (e) {
      if (!_disposed) await handleError(e);
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
    _locateCancel?.cancel();
    super.dispose();
  }
}
