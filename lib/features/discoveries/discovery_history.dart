import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../chat/chat_service.dart';

/// Uses the same history/progress endpoints as exploration restoration.
class DiscoveryHistory extends ChangeNotifier {
  DiscoveryHistory({
    required this.service,
    List<Map<String, dynamic>> initial = const [],
  }) : cards = [...initial];

  final ChatService service;
  final List<Map<String, dynamic>> cards;
  final _cancel = CancelToken();
  int _before = 0;
  bool loading = false, hasMore = true, _disposed = false;
  String? error;

  Future<void> loadMore() async {
    if (loading || !hasMore || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await service.request(
        '/explorations',
        query: {'before': _before},
        cancelToken: _cancel,
      );
      final more = page['hasMore'] == true;
      final next = page['nextBefore'];
      if (more &&
          (next is! int || next <= 0 || (_before > 0 && next >= _before))) {
        throw const ChatException('探索历史游标无效');
      }
      final batch = <Map<String, dynamic>>[];
      for (final turn in (page['items'] as List).whereType<Map>()) {
        if (turn['status'] != 'completed') continue;
        final task = turn['taskId'];
        if (task is! String || task.isEmpty) continue;
        final result = await service.request(
          '/explorations/${Uri.encodeComponent(task)}/progress',
          cancelToken: _cancel,
        );
        if (_disposed) return;
        for (final card in (result['cards'] as List? ?? []).whereType<Map>()) {
          batch.add({
            ...Map<String, dynamic>.from(card),
            'taskId': task,
            'createdAt':
                card['createdAt'] ?? turn['completedAt'] ?? turn['createdAt'],
          });
        }
      }
      if (_disposed) return;
      for (final card in batch) {
        final index = cards.indexWhere(
          (old) =>
              old['taskId'] == card['taskId'] &&
              old['materialId'] == card['materialId'],
        );
        if (index < 0) {
          cards.add(card);
        } else {
          cards[index] = {...cards[index], ...card};
        }
      }
      hasMore = more;
      if (more) _before = next as int;
    } catch (_) {
      if (!_disposed) error = '发现加载失败，请重试';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel.cancel('Discovery history closed');
    super.dispose();
  }
}
