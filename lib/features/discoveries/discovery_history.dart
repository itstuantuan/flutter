import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../chat/chat_service.dart';
import 'discovery_data.dart';

/// Uses the same history/progress endpoints as exploration restoration.
class DiscoveryHistory extends ChangeNotifier {
  DiscoveryHistory({
    required this.service,
    List<Map<String, dynamic>> initial = const [],
  }) : cards = [...initial];

  final ChatService service;
  final List<Map<String, dynamic>> cards;
  final _cancel = CancelToken();
  String _cursor = '', query = '';
  bool history = false;
  int _generation = 0;
  Future<void> search(String value, {bool? onlyHistory}) async {
    query = value.trim();
    history = onlyHistory ?? history;
    _generation++;
    _cursor = '';
    cards.clear();
    hasMore = true;
    loading = false;
    await loadMore();
  }

  bool loading = false, hasMore = true, _disposed = false;
  String? error;

  Future<void> loadMore() async {
    if (loading || !hasMore || _disposed) return;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await service.request(
        '/discoveries',
        query: {'cursor': _cursor, 'q': query, 'history': history, 'limit': 20},
        cancelToken: _cancel,
      );
      if (_disposed || generation != _generation) return;
      if (_cursor.isEmpty) cards.clear();
      for (final item in (page['items'] as List).whereType<Map>()) {
        final card = discoveryCard(Map<String, dynamic>.from(item));
        card['_history'] = history;
        service.discoveries.accept(card);
        final index = cards.indexWhere(
          (old) => card['materialId'] != null
              ? old['materialId'] == card['materialId']
              : old['discoveryId'] == card['discoveryId'],
        );
        if (index < 0) cards.add(card);
      }
      hasMore = page['hasMore'] == true;
      _cursor = page['nextCursor'] as String? ?? '';
      if (hasMore && _cursor.isEmpty) throw const ChatException('探索历史游标无效');
    } catch (_) {
      if (!_disposed && generation == _generation) error = '发现加载失败，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
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
