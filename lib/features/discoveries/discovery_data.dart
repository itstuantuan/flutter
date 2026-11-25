import '../chat/chat_service.dart';
import '../../core/network/api_client.dart';

Map<String, dynamic> discoveryCard(Map<String, dynamic> item) => {
  ...?((item['card'] as Map?)?.cast<String, dynamic>()),
  if (item['available'] == false) 'title': '内容不可用',
  for (final key in [
    'discoveryId',
    'taskId',
    'sessionId',
    'ordinal',
    'available',
    'state',
    'recommendedTime',
  ])
    if (item.containsKey(key)) key: item[key],
};

/// Owned by the authenticated service, so state never crosses account sessions.
class DiscoveryData {
  DiscoveryData(this.service);
  final ChatService service;
  final states = <String, Map<String, dynamic>>{};
  Future<void> _writes = Future.value();

  void accept(Map<String, dynamic> card) {
    final material = card['materialId'];
    final state = card['state'];
    if (material is String && state is Map) {
      final next = Map<String, dynamic>.from(state);
      if ((next['revision'] as int? ?? 0) >=
          (states[material]?['revision'] as int? ?? -1)) {
        states[material] = next;
      }
    }
  }

  Future<Map<String, dynamic>> detail(Map<String, dynamic> card) async {
    final id = card['discoveryId'];
    final task = card['taskId'] ?? card['_chatTaskId'];
    final material = card['materialId'];
    if (id == null && (task == null || material == null)) {
      throw const ChatException('这条发现缺少定位信息');
    }
    final item = await service.request(
      id != null
          ? '/discoveries/${Uri.encodeComponent('$id')}'
          : '/explorations/${Uri.encodeComponent('$task')}/cards/${Uri.encodeComponent('$material')}',
    );
    if (item['available'] == false || item['card'] is! Map) {
      throw const ChatException('内容不可用');
    }
    final result = discoveryCard(item);
    accept(result);
    return result;
  }

  Future<void> stateWrite(
    Map<String, dynamic> card,
    String operation, {
    String? action,
  }) {
    final next = _writes.then<void>((_) async {
      accept(card);
      if (states[card['materialId']]?['revision'] is! int) {
        await detail(card);
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final state = await service.request(
            '/discoveries/${Uri.encodeComponent(card['discoveryId'] as String)}/$operation',
            method: 'PUT',
            data: {
              'revision':
                  states[card['materialId']]?['revision'] ??
                  (card['state'] as Map?)?['revision'] ??
                  0,
              'action': ?action,
            },
          );
          accept({...card, 'state': state});
          return;
        } on DioException catch (e) {
          if (e.response?.statusCode != 409) rethrow;
          if (attempt == 1) {
            throw const ChatException('状态正在更新，请稍后重试');
          }
          await detail(card);
        }
      }
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> view(Map<String, dynamic> card, {bool close = false}) {
    final next = _writes.then<void>((_) async {
      final task = card['taskId'] ?? card['_chatTaskId'];
      if (task == null || card['materialId'] == null) return;
      final path = '/explorations/${Uri.encodeComponent('$task')}';
      for (var attempt = 0; attempt < 2; attempt++) {
        final progress = await service.request('$path/progress');
        final view = progress['view'] as Map? ?? {};
        final cards = (progress['cards'] as List? ?? [])
            .whereType<Map>()
            .toList();
        final index = cards.indexWhere(
          (c) => c['materialId'] == card['materialId'],
        );
        if (index < 0) return;
        try { 
          await service.request(
            '$path/view',
            method: 'PUT',
            data: {
              'revision': view['revision'] ?? 0,
              'lastMaterialId': card['materialId'],
              'listIndex': index,
              'displayedMaterialIds': {
                ...(view['displayedMaterialIds'] as List? ?? []),
                card['materialId'],
              }.toList(),
              'closeGroup': close,
            },
          );
          return;
        } on DioException catch (e) {
          if (e.response?.statusCode != 409) rethrow;
          if (attempt == 1) {
            throw const ChatException('状态正在更新，请稍后重试');
          }
        }
      }
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}
