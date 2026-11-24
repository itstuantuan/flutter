/// Keeps a bounded presentation snapshot separate from server history.
class DiscoveryInbox {
  List<Map<String, dynamic>> available = [], visible = [];
  final unread = <Object>{};
  final _known = <Object>{};
  bool ready = false, pending = false;
  int _newestTurn = -1;

  static Object identity(Map<String, dynamic> card) => (
    card['_chatTaskId'] ?? card['taskId'],
    card['materialId'] ?? card['title'],
  );

  bool update(
    List<Map<String, dynamic>> cards, {
    required bool snapshotReady,
    bool allowNew = true,
  }) {
    final previous = available;
    available = cards;
    final arrivals = <Object>{};
    for (final card in cards) {
      final key = identity(card);
      final turn = card['_chatTurnId'];
      if (_known.add(key) &&
          ready &&
          allowNew &&
          (turn is! int || turn >= _newestTurn)) {
        arrivals.add(key);
      }
    }
    for (final card in cards) {
      final turn = card['_chatTurnId'];
      if (turn is int && turn > _newestTurn) _newestTurn = turn;
    }
    if (!ready) {
      visible = cards.take(3).toList();
      ready = snapshotReady;
      return false;
    }
    final ordered = <Object>{};
    available = [
      for (final card in cards.where((c) => arrivals.contains(identity(c))))
        if (ordered.add(identity(card))) card,
      for (final old in previous)
        for (final card in cards.where((c) => identity(c) == identity(old)))
          if (ordered.add(identity(card))) card,
      for (final card in cards)
        if (ordered.add(identity(card))) card,
    ];
    if (arrivals.isNotEmpty) {
      unread.addAll(arrivals);
      pending = true;
      // Older notifications remain in All Discoveries, not in the badge count.
      unread.retainAll(available.take(3).map(identity).toSet());
    } else if (!pending) {
      // Refresh content without moving the card the user is reading.
      visible = [
        for (final old in visible)
          cards.where((c) => identity(c) == identity(old)).firstOrNull ?? old,
      ];
    }
    return arrivals.isNotEmpty;
  }

  void apply() {
    visible = available.take(3).toList();
    pending = false;
  }

  void locate(String? materialId, int? turnId) {
    final target = available
        .where(
          (c) =>
              (materialId == null || c['materialId'] == materialId) &&
              (turnId == null || c['_chatTurnId'] == turnId),
        )
        .firstOrNull;
    if (target == null) return;
    if (!visible.any((c) => identity(c) == identity(target))) {
      visible = [
        target,
        ...available.where((c) => identity(c) != identity(target)).take(2),
      ];
    }
  }
}
