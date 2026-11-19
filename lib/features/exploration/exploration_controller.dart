import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_service.dart';
import 'exploration_store.dart';
import 'discovery_policy.dart';

const interestIds = {
  '音乐': 'music',
  '游戏': 'games',
  '影视': 'film_tv',
  '动漫': 'anime',
  '旅游': 'travel',
  '宠物': 'pets',
  '美食': 'food',
  '阅读': 'reading',
  '吃瓜': 'trending',
};

class ExplorationController extends ChangeNotifier {
  ExplorationController({
    required this.service,
    required this.store,
    required String displayName,
    Future<void> Function()? onUnauthorized,
  }) {
    chat = ChatController(
      service,
      displayName: displayName,
      onUnauthorized: onUnauthorized,
      loadHome: _fetchHome,
      onCompletion: receiveCompletion,
    );
    chat.addListener(_notify);
  }
  final ChatService service;
  final ExplorationStore store;
  late final ChatController chat;
  Map<String, dynamic> home = {}, progress = {}, square = {};
  bool progressUnavailable = false;
  bool _squarePending = false;
  final _events = <String, Map<String, dynamic>>{};
  final _completedResults = <String, Map<String, dynamic>>{};
  final _displayed = <String>{};
  final _pendingAcks = <String, String>{};
  String? _pendingStartId, _watchTask;
  bool ready = false, busy = false, _disposed = false, _foreground = true;
  bool _polling = false, _acking = false;
  Future<void>? _initializing, _homeRequest, _historyRequest;
  Future<Map<String, dynamic>>? _homeFetch;
  int _homeCardsVersion = 0;
  bool _homeLoaded = false;
  bool get loadingCards =>
      cards.isEmpty && !_homeLoaded && error == null && chat.error == null;
  Future<void> _writeQueue = Future.value();
  Timer? _pollTimer;
  final _cancel = CancelToken();
  String? error;

  List<Map<String, dynamic>> get cards => (home['cards'] as List? ?? [])
      .map((card) => Map<String, dynamic>.from(card as Map))
      .toList();
  String? get activeTaskId =>
      (home['activeExploration'] as Map?)?['taskId'] as String?;
  List<Map<String, dynamic>> get pendingEvents =>
      _events.values
          .where((event) => !_displayed.contains(event['eventId']))
          .toList()
        ..sort(
          (a, b) => (a['completedAt'] as int? ?? 0).compareTo(
            b['completedAt'] as int? ?? 0,
          ),
        );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final saved = await store.read();
      if (_disposed) return;
      _displayed.addAll(List<String>.from(saved['displayed'] as List? ?? []));
      _pendingAcks.addAll(
        Map<String, String>.from(saved['pendingAcks'] as Map? ?? {}),
      );
      _pendingStartId = saved['pendingStartId'] as String?;
      final cached = saved['cards'] as List? ?? [];
      home = {'cards': cached.take(maxDiscoveryCards).toList()};
      ready = true;
      if (_foreground) {
        unawaited(chat.start());
        unawaited(retryAcknowledgements());
      }
    } catch (_) {
      error = '无法恢复探索状态，请退出后重试';
    }
    _notify();
  }

  Future<void> _save() {
    final snapshot = <String, dynamic>{
      'displayed': _displayed.toList(),
      'pendingAcks': {..._pendingAcks},
      'pendingStartId': _pendingStartId,
      'cards': cards.take(maxDiscoveryCards).toList(),
    };
    final next = _writeQueue.then((_) => store.write(snapshot));
    _writeQueue = next.catchError((_) {});
    return next;
  }

  void _cacheCards() {
    unawaited(
      _save().catchError((Object e) {
        if (kDebugMode) debugPrint('[Exploration] Card cache write failed: $e');
      }),
    );
  }

  void acceptHome(Map<String, dynamic> value) {
    if (_disposed) return;
    final previousCards = cards;
    final incoming = value['cards'] as List? ?? [];
    // Empty/next-day responses do not erase an already displayed discovery.
    home = {
      ...value,
      'cards': incoming.isEmpty
          ? previousCards
          : incoming.take(maxDiscoveryCards).toList(),
    };
    if (incoming.isNotEmpty) {
      ++_homeCardsVersion;
      _homeLoaded = true;
      _cacheCards();
    }
    _notify();
    if (incoming.isEmpty) {
      _historyRequest ??= _restoreLastDiscovery().whenComplete(() {
        _historyRequest = null;
        _homeLoaded = true;
        _notify();
      });
      unawaited(_historyRequest!.catchError((Object e) => reportError(e)));
    }
  }

  Future<void> _restoreLastDiscovery() async {
    final version = _homeCardsVersion;
    var before = 0;
    while (!_disposed) {
      final page = await service.request(
        '/explorations',
        query: {'before': before},
        cancelToken: _cancel,
      );
      if (_disposed || version != _homeCardsVersion) return;
      for (final raw in page['items'] as List) {
        final turn = raw as Map;
        if (turn['status'] != 'completed') continue;
        final task = turn['taskId'] as String;
        final progress = await service.request(
          '/explorations/${Uri.encodeComponent(task)}/progress',
          cancelToken: _cancel,
        );
        if (_disposed || version != _homeCardsVersion) return;
        final rawCards = progress['cards'] as List? ?? [];
        if (progress['phase'] != 'complete' || rawCards.isEmpty) continue;
        home = {
          ...home,
          'cards': [
            for (final rawCard in rawCards.take(maxDiscoveryCards))
              {
                'kind': 'discovery',
                'taskId': task,
                'materialId': (rawCard as Map)['materialId'],
                'title': rawCard['title'],
                'text': rawCard['reason'] ?? rawCard['summary'] ?? '',
                'coverUrl': rawCard['coverUrl'],
                'tags': rawCard['tags'],
              },
          ],
        };
        _cacheCards();
        _notify();
        return;
      }
      if (page['hasMore'] != true) return;
      final next = page['nextBefore'] as int;
      if (next <= 0 || (before > 0 && next >= before)) {
        throw const ChatException('探索历史游标无效');
      }
      before = next;
    }
  }

  Future<void> refreshHome() =>
      _homeRequest ??= _refreshHome().whenComplete(() => _homeRequest = null);
  Future<void> _refreshHome() async {
    await chat.initializeSession(cancelToken: _cancel);
    await _fetchHome();
  }

  // Startup/reconnect and explicit refresh share one in-flight home request.
  Future<Map<String, dynamic>> _fetchHome() =>
      _homeFetch ??= _fetchHomeOnce().whenComplete(() => _homeFetch = null);
  Future<Map<String, dynamic>> _fetchHomeOnce() async {
    final result = await service.request('/home', cancelToken: _cancel);
    if (!_disposed) acceptHome(result);
    return result;
  }

  Future<Map<String, dynamic>> interests() =>
      service.request('/me/interests', cancelToken: _cancel);
  Future<void> saveInterests(List<String> labels) async {
    final state = await service.request('/me', cancelToken: _cancel);
    final account = state['account'] as Map;
    await service.request(
      '/me/interests',
      method: 'PUT',
      data: {
        'revision': account['revision'],
        'categories': labels.map((label) => interestIds[label]!).toList(),
      },
      cancelToken: _cancel,
    );
  }

  Future<String?> startExploration({
    Future<bool> Function(Map<String, dynamic> selection)? confirmInterests,
    bool Function()? isCurrent,
  }) async {
    if (busy || _disposed) return null;
    busy = true;
    error = null;
    _notify();
    try {
      await initialize();
      if (!ready) throw const ChatException('无法恢复探索状态');
      await refreshHome();
      if (activeTaskId != null) {
        // An earlier POST may have succeeded despite a lost receipt.
        // Once home recovers that task, the next departure must use a new ID.
        if (_pendingStartId != null) {
          _pendingStartId = null;
          await _save();
        }
        return activeTaskId;
      }
      if ((home['capabilities'] as Map?)?['exploration'] == false) {
        throw const ChatException('探索服务暂未开启');
      }
      if (_disposed || (isCurrent != null && !isCurrent())) return null;
      final selection = await interests();
      if (selection['confirmed'] != true && confirmInterests != null) {
        if (!await confirmInterests(selection)) return null;
      }
      if (_disposed || (isCurrent != null && !isCurrent())) return null;
      _pendingStartId ??= newOperationId();
      // Persist before POST so an app restart cannot create a duplicate operation.
      await _save();
      final session = await chat.initializeSession(cancelToken: _cancel);
      final turn = await service.request(
        '/sessions/${Uri.encodeComponent(session)}/explorations',
        method: 'POST',
        data: {'clientMessageId': _pendingStartId, 'need': ''},
        cancelToken: _cancel,
      );
      final task = turn['taskId'] as String;
      _pendingStartId = null;
      await _save();
      // This is a task receipt, never a chat turn or synthetic discovery.
      home = {
        ...home,
        'activeExploration': {'taskId': task, 'phase': 'searching'},
      };
      _notify();
      return task;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await refreshHome();
        if (activeTaskId != null) {
          _pendingStartId = null;
          await _save();
          return activeTaskId;
        }
      }
      await reportError(e);
      return null;
    } catch (e) {
      await reportError(e);
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  void receiveCompletion(Map<String, dynamic> event) {
    if (_disposed) return;
    final id = event['eventId'];
    if (event['type'] != 'exploration_completed' ||
        id is! String ||
        event['taskId'] is! String ||
        event['sessionId'] != chat.sessionId ||
        (event['cards'] as List? ?? []).isEmpty) {
      return;
    }
    _completedResults[event['taskId'] as String] = event;
    if (_watchTask == event['taskId']) {
      progress = {...event, 'phase': 'complete'};
      progressUnavailable = false;
      _pollTimer?.cancel();
      _notify();
    }
    if (_displayed.contains(id)) {
      if (_pendingAcks.containsKey(id)) unawaited(retryAcknowledgements());
      return;
    }
    _events[id] = event;
    _notify();
    unawaited(refreshHome().catchError((Object e) => reportError(e)));
  }

  /// Retains the same result after its presentation acknowledgement removes it
  /// from the pending queue. Re-entered pages can recover it from the server.
  Future<Map<String, dynamic>?> discoveryResult(String taskId) async {
    final completed = _completedResults[taskId];
    if (completed != null) return completed;
    final result = await service.request(
      '/explorations/${Uri.encodeComponent(taskId)}/progress',
      cancelToken: _cancel,
    );
    if (result['phase'] != 'complete' ||
        (result['cards'] as List? ?? []).isEmpty) {
      return null;
    }
    return {...result, 'taskId': taskId};
  }

  Future<void> refreshCompletions() async {
    final events = await service.requestList(
      '/explorations/completions',
      cancelToken: _cancel,
    );
    if (_disposed) return;
    for (final event in events) {
      receiveCompletion(event);
    }
    await retryAcknowledgements();
  }

  /// Called only after the result has actually been presented on screen.
  Future<void> markDisplayed(Map<String, dynamic> event) async {
    final id = event['eventId'] as String;
    if (_displayed.contains(id)) return;
    _displayed.add(id);
    _pendingAcks[id] = event['taskId'] as String;
    try {
      await _save();
    } catch (_) {
      _displayed.remove(id);
      _pendingAcks.remove(id);
      rethrow;
    }
    _events.remove(id);
    _notify();
    await retryAcknowledgements();
  }

  Future<void> acknowledgeTask(String taskId) async {
    for (final event
        in pendingEvents.where((e) => e['taskId'] == taskId).toList()) {
      await markDisplayed(event);
    }
  }

  Future<void> retryAcknowledgements() async {
    if (_acking || _disposed || !_foreground || !ready) return;
    _acking = true;
    try {
      for (final entry in _pendingAcks.entries.toList()) {
        try {
          await service.requestData(
            '/explorations/${Uri.encodeComponent(entry.value)}/acknowledgement',
            method: 'PUT',
            cancelToken: _cancel,
          );
          _pendingAcks.remove(entry.key);
          await _save();
        } catch (e) {
          // Keep the persisted ledger for the next foreground/reconnect attempt.
          _pendingAcks[entry.key] = entry.value;
          if (e is DioException && e.response?.statusCode == 401) {
            await reportError(e);
          }
          break;
        }
      }
    } finally {
      _acking = false;
    }
  }

  void watchPlaza(String taskId) {
    _watchTask = taskId;
    progress = {};
    square = {};
    progressUnavailable = false;
    _pollTimer?.cancel();
    if (_foreground) unawaited(_poll());
  }

  void stopWatchingPlaza() {
    _watchTask = null;
    _pollTimer?.cancel();
  }

  Future<void> _refreshSquare(String task) async {
    if (_squarePending) return;
    _squarePending = true;
    try {
      final result = await service.request(
        '/explorations/${Uri.encodeComponent(task)}/square',
        cancelToken: _cancel,
      );
      if (!_disposed &&
          _watchTask == task &&
          (result['taskId'] == null || result['taskId'] == task)) {
        square = result;
        _notify();
      }
    } catch (_) {
      // Elapsed time is optional; progress and completion must remain usable.
    } finally {
      _squarePending = false;
    }
  }

  Future<void> _poll() async {
    final task = _watchTask;
    if (_disposed || !_foreground || _polling || task == null) return;
    _polling = true;
    unawaited(_refreshSquare(task));
    var finished = false;
    try {
      final result = await service.request(
        '/explorations/${Uri.encodeComponent(task)}/progress',
        cancelToken: _cancel,
      );
      if (_disposed || _watchTask != task) return;
      final completed = _completedResults[task];
      progress = completed == null
          ? result
          : {...completed, 'phase': 'complete'};
      progressUnavailable = false;
      finished = {'complete', 'empty', 'failed'}.contains(progress['phase']);
      _notify();
      if (finished) {
        await refreshHome();
        await refreshCompletions();
      }
    } catch (e) {
      finished = false;
      if (!_disposed && _watchTask == task) {
        if (_completedResults.containsKey(task)) {
          finished = true;
        } else {
          progressUnavailable = true;
          await reportError(e);
        }
      }
    } finally {
      _polling = false;
      if (!_disposed && _foreground && _watchTask != null) {
        if (_watchTask != task) {
          unawaited(_poll());
        } else if (!finished) {
          _pollTimer = Timer(const Duration(seconds: 3), _poll);
        }
      }
    }
  }

  Future<void> reportError(Object e) async {
    if (_disposed) return;
    if (e is DioException && e.type == DioExceptionType.cancel) return;
    error = e is ChatException
        ? e.message
        : e is DioException
        ? e.userMessage
        : '探索暂时不可用，请稍后重试';
    _notify();
    if (e is DioException && e.response?.statusCode == 401) {
      await chat.handleError(e);
    }
  }

  void pause() {
    _foreground = false;
    _pollTimer?.cancel();
    chat.pause();
  }

  void resume() {
    if (_disposed) return;
    _foreground = true;
    if (ready) {
      unawaited(chat.start());
      unawaited(retryAcknowledgements());
      if (_watchTask != null) unawaited(_poll());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _cancel.cancel();
    chat.removeListener(_notify);
    chat.dispose();
    super.dispose();
  }
}
