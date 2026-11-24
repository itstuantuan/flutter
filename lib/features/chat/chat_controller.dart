import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../exploration/discovery_policy.dart';
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
    this.onExplorationProgress,
    this._sessionId,
  });
  final ChatService service;
  final Future<Map<String, dynamic>> Function()? loadHome;
  final String displayName;
  final Future<void> Function()? onUnauthorized;
  final void Function(Map<String, dynamic>)? onHome, onCompletion;
  final void Function(Map<String, dynamic>)? onExplorationProgress;
  final _turns = <int, Map<String, dynamic>>{};
  final _liveReplies = <int>{};
  final _outgoingText = <String, ChatMessage>{};
  final _textRequests = <CancelToken>{};
  final _discoveryBatches =
      <String, ({Set<String> materials, int? completedAt})>{};
  final _discoveryChecks = <String, CancelToken>{};
  String? _sessionId, error;
  Future<String>? _initializing;
  String? _pendingId, _pendingFingerprint;
  bool loading = true, sending = false, locating = false;
  bool _disposed = false, _active = false, _authFailed = false;
  int _generation = 0, _attempt = 0;
  CancelToken? _connection, _sendCancel, _locateCancel;
  Timer? _reconnect;
  int? _olderBefore;
  bool _loadedLatestHistory = false;
  CancelToken? _olderHistoryCancel;
  bool get hasOlderMessages => _olderBefore != null;
  bool get loadingOlderMessages => _olderHistoryCancel != null;
  int? anchorTurnId;
  int locationRevision = 0;
  String? referenceTaskId, referenceMaterialId;

  String? get sessionId => _sessionId;
  bool get unauthorized => _authFailed;

  List<ChatMessage> get messages {
    final loaded = _loadedDiscoveryMaterials();
    final turns = _orderedTurns();
    return [
      for (final turn in turns)
        if (_canShowTurn(turn, loaded)) ...[
          if (_hasUserMessage(turn))
            ChatMessage(
              (turn['userText'] as String? ?? '').isNotEmpty
                  ? turn['userText'] as String
                  : '语音消息',
              isInterfaceText: (turn['userText'] as String? ?? '').isEmpty,
              isUser: true,
              createdAt: _createdAt(turn),
              clientMessageId: turn['clientMessageId'] as String?,
            ),
          if ((turn['assistantText'] as String? ?? '').isNotEmpty ||
              _cards(turn).isNotEmpty)
            ChatMessage(
              turn['assistantText'] as String? ?? '',
              turnId: turn['id'] as int,
              referenceTaskId:
                  _discoveryTask(turn) ?? turn['referenceTaskId'] as String?,
              cards: _cards(turn),
              createdAt: _createdAt(turn),
              animateReply: _liveReplies.contains(turn['id']),
            )
          else if (_hasUserMessage(turn) &&
              (turn['status'] == 'queued' || turn['status'] == 'processing'))
            ChatMessage(
              '',
              turnId: turn['id'] as int,
              createdAt: _createdAt(turn),
              isThinking: true,
            ),
          if (turn['status'] == 'failed')
            ChatMessage(
              '这次回复未完成，请重新发送消息再试。${_failureCode(turn)}',
              isInterfaceText: true,
              createdAt: _createdAt(turn),
              turnId: (turn['assistantText'] as String? ?? '').isEmpty
                  ? turn['id'] as int
                  : null,
            ),
        ],
      ..._outgoingText.values,
    ];
  }

  bool _hasUserMessage(Map<String, dynamic> turn) =>
      !{'welcome', 'discovery'}.contains(turn['messageType']) &&
      ((turn['userText'] as String? ?? '').isNotEmpty ||
          (turn['attachmentIds'] as List? ?? []).isNotEmpty);

  bool _isDiscovery(Map<String, dynamic> turn) =>
      turn['messageType'] == 'discovery' || turn['messageType'] == 'explore';

  String? _discoveryTask(Map<String, dynamic> turn) {
    if (!_isDiscovery(turn)) return null;
    final task =
        turn['referenceTaskId'] ??
        (turn['messageType'] == 'explore' ? turn['taskId'] : null);
    return task is String && task.isNotEmpty ? task : null;
  }

  int? _timestamp(Object? value) => value is int && value > 0 ? value : null;

  int? _turnTime(Map<String, dynamic> turn) =>
      _discoveryBatches[_discoveryTask(turn)]?.completedAt ??
      _timestamp(turn['createTime']);

  DateTime? _createdAt(Map<String, dynamic> turn) {
    final time = _turnTime(turn);
    return time == null ? null : DateTime.fromMillisecondsSinceEpoch(time);
  }

  List<Map<String, dynamic>> _orderedTurns() {
    final byId = _turns.keys.toList()..sort();
    final positions = <int, int>{};
    var lastChatTime = 0;
    for (final id in byId) {
      final turn = _turns[id]!;
      final time = _turnTime(turn);
      if (!_isDiscovery(turn) && turn['messageType'] != 'explore_task') {
        lastChatTime = max(lastChatTime, time ?? 0);
      }
      // Keep ordinary chat in server order and place discoveries by their
      // original timestamp, even if the server inserted them later.
      positions[id] = _isDiscovery(turn) ? time ?? lastChatTime : lastChatTime;
    }
    byId.sort((a, b) {
      final timeOrder = positions[a]!.compareTo(positions[b]!);
      return timeOrder == 0 ? a.compareTo(b) : timeOrder;
    });
    return [for (final id in byId) _turns[id]!];
  }

  Set<String> _materialIds(Object? cards) => {
    if (cards is List)
      for (final card in cards.whereType<Map>())
        if (card['materialId'] case final String id when id.isNotEmpty) id,
  };

  Map<String, Set<String>> _loadedDiscoveryMaterials() {
    final loaded = <String, Set<String>>{};
    for (final turn in _turns.values) {
      final task = _discoveryTask(turn);
      if (task == null) continue;
      final cards = _materialIds(_cards(turn));
      if (cards.isNotEmpty) (loaded[task] ??= {}).addAll(cards);
    }
    return loaded;
  }

  bool _canShowTurn(
    Map<String, dynamic> turn,
    Map<String, Set<String>> loaded,
  ) {
    if (turn['messageType'] == 'explore_task') return false;
    if (!_isDiscovery(turn)) return true;
    if (turn['status'] != 'completed') return turn['status'] == 'failed';
    final task = _discoveryTask(turn);
    if (task == null || !loaded.containsKey(task)) return true;
    final cards = loaded[task]!;
    final batch = _discoveryBatches[task];
    return batch == null
        ? cards.length >= maxDiscoveryCards
        : cards.containsAll(batch.materials);
  }

  void _checkDiscoveryBatches(Set<String> tasks) {
    if (tasks.isEmpty) return;
    final loaded = _loadedDiscoveryMaterials();
    for (final task in tasks) {
      final cards = loaded[task];
      if (cards == null ||
          cards.length >= maxDiscoveryCards ||
          _discoveryBatches.containsKey(task) ||
          _discoveryChecks.containsKey(task)) {
        continue;
      }
      unawaited(_checkDiscoveryBatch(task));
    }
  }

  Future<void> _checkDiscoveryBatch(String task) async {
    final cancel = _discoveryChecks[task] = CancelToken();
    try {
      final progress = await service.request(
        '/explorations/${Uri.encodeComponent(task)}/progress',
        cancelToken: cancel,
      );
      if (_disposed ||
          _discoveryBatches.containsKey(task) ||
          progress['phase'] != 'complete' ||
          (progress['taskId'] ?? task) != task ||
          (progress['sessionId'] ?? _sessionId) != _sessionId) {
        return;
      }
      _recordDiscoveryBatch(
        task,
        progress['cards'],
        progress['fullAvailableAt'],
      );
    } catch (e) {
      if (!_disposed && e is DioException && e.response?.statusCode == 401) {
        await handleError(e);
      }
      // A subsequent history snapshot or completion event can confirm the batch.
    } finally {
      _discoveryChecks.remove(task);
    }
  }

  void _recordDiscoveryBatch(String task, Object? cards, Object? completedAt) {
    final materials = _materialIds(cards);
    if (materials.isEmpty) return;
    _discoveryBatches[task] = (
      materials: materials,
      completedAt: _timestamp(completedAt),
    );
    _notify();
  }

  void _receiveCompletion(Map<String, dynamic> event) {
    final task = event['taskId'];
    if (event['type'] == 'exploration_completed' &&
        event['sessionId'] == _sessionId &&
        task is String) {
      _recordDiscoveryBatch(task, event['cards'], event['completedAt']);
    }
    onCompletion?.call(event);
  }

  List<Map<String, dynamic>> _cards(Map<String, dynamic> turn) {
    // Only render the backend's published discovery; never create one from an event.
    if (!_isDiscovery(turn) || turn['status'] != 'completed') return const [];
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
    final touchedDiscoveries = <String>{};
    for (final raw in turns) {
      final turn = Map<String, dynamic>.from(raw as Map);
      final id = turn['id'] as int;
      _outgoingText.remove(turn['clientMessageId']);
      final old = _turns[id];
      if (old == null ||
          (turn['updateTime'] as int? ?? 0) >=
              (old['updateTime'] as int? ?? 0)) {
        _turns[id] = turn;
        if (_discoveryTask(turn) case final String task) {
          touchedDiscoveries.add(task);
        }
        if (live && old?['assistantText'] != turn['assistantText']) {
          _liveReplies.add(id);
        } else if (!live) {
          _liveReplies.remove(id);
        }
      }
    }
    _checkDiscoveryBatches(touchedDiscoveries);
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
    final latest = await service.request(base, cancelToken: cancel);
    if (_disposed || cancel.isCancelled) return;
    if (!_loadedLatestHistory) {
      _olderBefore = _olderCursor(latest);
      _loadedLatestHistory = true;
    }
    merge(latest);
  }

  int? _olderCursor(Map<String, dynamic> page) {
    if (page['hasMore'] != true) return null;
    final turns = page['turns'] as List;
    if (turns.isEmpty) throw const ChatException('聊天历史游标无效');
    return turns.map((turn) => (turn as Map)['id'] as int).reduce(min);
  }

  Future<void> loadOlderMessages() async {
    final before = _olderBefore;
    final session = _sessionId;
    if (_disposed ||
        _authFailed ||
        loadingOlderMessages ||
        before == null ||
        session == null) {
      return;
    }
    final cancel = _olderHistoryCancel = CancelToken();
    _notify();
    try {
      final page = await service.request(
        '/sessions/${Uri.encodeComponent(session)}/messages',
        query: {'before': before},
        cancelToken: cancel,
      );
      if (_disposed) return;
      final next = _olderCursor(page);
      if (next != null && (next <= 0 || next >= before)) {
        throw const ChatException('聊天历史游标无效');
      }
      _olderBefore = next;
      merge(page);
    } catch (e) {
      if (!_disposed) await handleError(e);
    } finally {
      _olderHistoryCancel = null;
      _notify();
    }
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
          _receiveCompletion(event);
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
        } else if (event.type == 'exploration_progress') {
          onExplorationProgress?.call(
            Map<String, dynamic>.from(jsonDecode(event.data) as Map),
          );
        } else if (event.type == 'exploration_completed') {
          _receiveCompletion(
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
      // A task may publish one turn per card. The API anchor identifies the
      // task's first turn, so resolve the selected material within that task.
      final selectedTurn = materialId == null
          ? null
          : _turns.values
                .where(
                  (turn) =>
                      (turn['id'] == anchor ||
                          turn['referenceTaskId'] == taskId) &&
                      _cards(turn)
                          .any((card) => card['materialId'] == materialId),
                )
                .firstOrNull;
      setLocation(
        selectedTurn?['id'] as int? ?? anchor,
        taskId: taskId,
        materialId: materialId,
      );
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

  void setLocation(int turnId, {required String taskId, String? materialId}) {
    anchorTurnId = turnId;
    referenceTaskId = taskId;
    referenceMaterialId = materialId;
    locationRevision++;
  }

  void referenceDiscovery(Map<String, dynamic>? card) {
    referenceTaskId = (card?['_chatTaskId'] ?? card?['taskId']) as String?;
    referenceMaterialId = card?['materialId'] as String?;
    _notify();
  }

  void clearLocation() {
    _locateCancel?.cancel();
    locating = false;
    anchorTurnId = null;
    referenceTaskId = null;
    referenceMaterialId = null;
  }

  Map<String, dynamic> _messageBody(
    String text,
    List<String> attachmentIds,
  ) => {
    'message': text,
    'attachmentIds': attachmentIds,
    if (referenceTaskId != null) 'referenceTaskId': referenceTaskId,
    if (referenceMaterialId != null) 'referenceMaterialId': referenceMaterialId,
  };

  Future<Map<String, dynamic>> _postMessage(
    String id,
    Map<String, dynamic> body,
    CancelToken cancel,
  ) => service.request(
    '/sessions/${Uri.encodeComponent(_sessionId!)}/messages',
    method: 'POST',
    data: {'clientMessageId': id, ...body},
    cancelToken: cancel,
  );

  bool submitText(String text) {
    text = text.trim();
    if (_disposed ||
        _authFailed ||
        _sessionId == null ||
        locating ||
        text.isEmpty) {
      return false;
    }
    if (text.length > 4000) {
      error = '单条消息最多 4000 字';
      _notify();
      return false;
    }
    final id = newOperationId();
    final body = _messageBody(text, const []);
    _outgoingText[id] = ChatMessage(
      text,
      isUser: true,
      createdAt: DateTime.now(),
      clientMessageId: id,
    );
    error = null;
    _notify();
    unawaited(_sendText(id, body));
    return true;
  }

  Future<void> _sendText(String id, Map<String, dynamic> body) async {
    final cancel = CancelToken();
    _textRequests.add(cancel);
    try {
      final turn = await _postMessage(id, body, cancel);
      if (_disposed) return;
      merge({
        'turns': [
          {...turn, 'clientMessageId': id},
        ],
      }, live: true);
    } catch (e) {
      // The stream can acknowledge the message before the POST returns.
      if (!_disposed && _outgoingText.containsKey(id)) {
        await handleError(e);
      }
    } finally {
      _textRequests.remove(cancel);
    }
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
    final body = _messageBody(text, attachmentIds);
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
      final turn = await _postMessage(_pendingId!, body, cancel);
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
    for (final cancel in _textRequests) {
      cancel.cancel();
    }
    _locateCancel?.cancel();
    _olderHistoryCancel?.cancel();
    for (final cancel in _discoveryChecks.values) {
      cancel.cancel();
    }
    super.dispose();
  }
}
