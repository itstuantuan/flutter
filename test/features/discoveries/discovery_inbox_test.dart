import 'package:bots/features/chat/discovery_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> card(int n) => {'materialId': '$n', '_chatTaskId': 'task$n', '_chatTurnId': n, 'title': '发现$n'};
void main() {
  test('latest three replace individually; older history never alerts', () {
    final box = DiscoveryInbox();
    box.update([card(3), card(2), card(1)], snapshotReady: true);
    expect(box.unread, isEmpty);
    expect(box.update([card(4), card(3), card(2), card(1)], snapshotReady: true), isTrue);
    expect(box.visible.first['materialId'], '3');
    box.apply();
    expect(box.visible.map((c) => c['materialId']), ['4', '3', '2']);
    expect(box.update([card(4), card(3), card(2), card(1), card(0)], snapshotReady: true), isFalse);
    box.locate('0', 0);
    expect(box.visible.length, 3);
    expect(box.visible.any((c) => c['materialId'] == '0'), isTrue);
  });
  test('initial loading and repeated snapshots do not produce unread alerts', () {
    final box = DiscoveryInbox();
    box.update([], snapshotReady: false);
    expect(box.update([card(1)], snapshotReady: true), isFalse);
    expect(box.unread, isEmpty);
    expect(box.update([card(2), card(1)], snapshotReady: true), isTrue);
    expect(box.update([card(2), card(1)], snapshotReady: true), isFalse);
    expect(box.unread.length, 1);
  });
  test('new home card without a turn is inserted ahead of existing messages', () {
    final box = DiscoveryInbox();
    box.update([card(3), card(2), card(1)], snapshotReady: true);
    final home = {'materialId': 'home', 'taskId': 'home-task'};
    box.update([card(3), card(2), card(1), home], snapshotReady: true);
    box.apply();
    expect(box.visible.first['materialId'], 'home');
    box.update([card(3), card(2), card(1), home], snapshotReady: true);
    box.apply();
    expect(box.visible.first['materialId'], 'home');
  });
}
