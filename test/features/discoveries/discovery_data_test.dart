import 'dart:async';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/discoveries/discovery_data.dart';
import 'package:bots/features/discoveries/discovery_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../exploration/fakes.dart';

class ProtocolService extends FakeBotService {
  int revision = 0;
  bool conflict = true;
  final revisions = <int>[];
  final searches = <String, Completer<Map<String, dynamic>>>{};
  Map<String, dynamic> get item => {
    'discoveryId': 'd',
    'taskId': 't',
    'sessionId': 's',
    'available': true,
    'card': {'materialId': 'm', 'title': '正文命中'},
    'state': {'revision': revision, 'feedback': 'none'},
  };
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    if (path == '/discoveries') {
      return searches.putIfAbsent(query!['q'] as String, Completer.new).future;
    }
    if (method == 'GET') return item;
    revisions.add((data as Map)['revision'] as int);
    if (conflict) {
      conflict = false;
      revision = 3;
      final options = RequestOptions(path: path);
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 409),
      );
    }
    expect(data['revision'], revision);
    return {'revision': ++revision, 'feedback': data['action'] ?? 'none'};
  }
}

void main() {
  test('missing state is fetched instead of guessing revision zero', () async {
    final service = ProtocolService()
      ..conflict = false
      ..revision = 7;
    final card = discoveryCard(service.item)..remove('state');
    await service.discoveries.stateWrite(card, 'feedback', action: 'like');
    expect(service.revisions, [7]);
  });

  test(
    'displayed and feedback serialize and recover a conflicting revision',
    () async {
      final service = ProtocolService();
      final card = discoveryCard(service.item);
      service.discoveries.accept(card);
      await Future.wait([
        service.discoveries.stateWrite(card, 'displayed'),
        service.discoveries.stateWrite(card, 'feedback', action: 'like'),
      ]);
      expect(service.revisions, [0, 3, 4]);
      expect(service.discoveries.states['m']!['feedback'], 'like');
      service.discoveries.accept(card);
      expect(service.discoveries.states['m']!['revision'], 5);
    },
  );
  test(
    'late search response cannot replace newer results or loading state',
    () async {
      final service = ProtocolService();
      final history = DiscoveryHistory(service: service);
      final old = history.search('old');
      final fresh = history.search('new');
      service.searches['new']!.complete({
        'items': [service.item],
        'hasMore': false,
      });
      await fresh;
      service.searches['old']!.complete({'items': [], 'hasMore': false});
      await old;
      expect(history.cards.single['title'], '正文命中');
      expect(history.loading, false);
      history.dispose();
    },
  );
}
