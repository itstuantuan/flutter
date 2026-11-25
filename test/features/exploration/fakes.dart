import 'dart:async';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/exploration/exploration_store.dart';

class MemoryExplorationStore implements ExplorationStore {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) throw StateError('disk');
    value = data;
  }
}

class FakeBotService extends ChatService {
  FakeBotService()
    : super(
        client: ApiClient(baseUrl: 'https://test'),
        headers: () async => {},
      );
  final calls = <Map<String, dynamic>>[];
  final events = StreamController<SseEvent>.broadcast();
  bool confirmed = false, timeoutStart = false, failAck = false;
  int starts = 0;
  bool failProgress = false;
  Completer<void>? homeGate, progressGate;
  String? activeTask;
  List<String> selectedInterests = ['music'];
  List<Map<String, dynamic>> homeCards = [];
  List<Map<String, dynamic>> historyItems = [];
  List<Map<String, dynamic>> completions = [];
  Map<String, dynamic> square = {'elapsedSeconds': 12};
  Map<String, dynamic> progress = {'phase': 'searching', 'cards': []};
  Map<String, dynamic> located = {
    'anchorTurnId': 42,
    'turns': [],
    'hasBefore': false,
    'hasAfter': false,
  };

  void _record(
    String path,
    String method,
    Object? data,
    Map<String, dynamic>? query,
  ) =>
      calls.add({'path': path, 'method': method, 'data': data, 'query': query});

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    _record(path, method, data, query);
    if (path == '/me') {
      return {
        'initialized': true,
        'sessionId': 'session-1',
        'account': {'revision': 3},
      };
    }
    if (path == '/home') {
      await homeGate?.future;
      return {
        'sessionId': 'session-1',
        'cards': homeCards,
        'activeExploration': activeTask == null ? null : {'taskId': activeTask},
        'capabilities': {'exploration': true},
      };
    }
    if (path == '/me/interests') {
      if (method == 'PUT') {
        confirmed = true;
        return {'revision': 4};
      }
      return {'confirmed': confirmed, 'selected': selectedInterests};
    }
    if (path == '/explorations') {
      return {'items': historyItems, 'hasMore': false};
    }
    if (path.endsWith('/progress')) {
      final snapshot = progress;
      await progressGate?.future;
      if (failProgress) throw const ChatException('进度连接失败');
      return snapshot;
    }
    if (path.contains('/cards/'))
      return {
        'discoveryId': 'd-test',
        'taskId': 'task-1',
        'sessionId': 'session-1',
        'card': (progress['cards'] as List).first,
        'state': {'revision': 0, 'feedback': 'none'},
      };
    if (path.endsWith('/displayed') || path.endsWith('/feedback'))
      return {
        'revision': ((data as Map)['revision'] as int) + 1,
        'feedback': data['action'] ?? 'none',
      };
    if (path.endsWith('/auto-popup'))
      return {
        'show': true,
        'view': {'revision': 1},
      };
    if (path.endsWith('/view')) return {'revision': 2};
    if (path.endsWith('/square')) return square;
    if (path.contains('/locate/')) return located;
    if (path.endsWith('/explorations') && method == 'POST') {
      starts++;
      if (timeoutStart) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionTimeout,
        );
      }
      activeTask = 'task-1';
      return {
        'taskId': activeTask,
        'messageType': 'explore_task',
        'status': 'queued',
      };
    }
    if (path.endsWith('/messages') || path.endsWith('/messages/after')) {
      if (method == 'POST') {
        return {
          'id': 100,
          'userText': (data as Map)['message'],
          'assistantText': '',
          'status': 'queued',
          'messageType': 'chat',
          'updateTime': 1,
        };
      }
      return {'turns': [], 'hasMore': false};
    }
    throw StateError('Unexpected request $method $path');
  }

  @override
  Future<List<Map<String, dynamic>>> requestList(
    String path, {
    CancelToken? cancelToken,
  }) async {
    _record(path, 'GET', null, null);
    if (path.endsWith('/discoveries')) return [];
    return completions;
  }

  @override
  Future<Object?> requestData(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Map<String, String> extraHeaders = const {},
  }) async {
    _record(path, method, data, query);
    if (failAck) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionTimeout,
      );
    }
    return null;
  }

  @override
  Stream<SseEvent> subscribe(String sessionId, CancelToken cancel) {
    final controller = StreamController<SseEvent>();
    final subscription = events.stream.listen(controller.add);
    cancel.whenCancel.then((_) async {
      await subscription.cancel();
      await controller.close();
    });
    return controller.stream;
  }
}

Map<String, dynamic> discoveryTurn({int id = 42, String task = 'task-1'}) => {
  'id': id,
  'taskId': 'discovery-message-own-id',
  'referenceTaskId': task,
  'messageType': 'discovery',
  'userText': '',
  'assistantText': '后端完整分享',
  'status': 'completed',
  'updateTime': 3,
  'exploration': {
    'cards': [
      for (var i = 1; i <= 3; i++)
        {
          'materialId': 'material-$i',
          'title': '发现$i',
          'content': '发现内容$i',
          'reason': '推荐理由$i',
        },
    ],
  },
};
Map<String, dynamic> completionEvent({String task = 'task-1'}) => {
  'eventId': task,
  'type': 'exploration_completed',
  'taskId': task,
  'sessionId': 'session-1',
  'turnId': 42,
  'completedAt': 123,
  'cards': (discoveryTurn()['exploration'] as Map)['cards'],
};
