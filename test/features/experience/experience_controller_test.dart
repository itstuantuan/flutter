import 'package:flutter_test/flutter_test.dart';
import 'package:bots/features/experience/experience_controller.dart';
import 'package:bots/features/experience/experience_store.dart';

class MemoryStore implements ExperienceStore {
  Map<String, dynamic>? data;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('storage unavailable');
    data = value;
  }
}

void main() {
  test('恢复角色、兴趣、任务和已读；重复开始不重置任务', () async {
    final store = MemoryStore();
    var now = DateTime.utc(2026, 11, 10);
    final flow = ExperienceController(store, clock: () => now);
    await flow.load();
    await flow.setName('小明');
    await flow.bind('milo');
    await flow.bind('nova');
    expect(flow.character.id, 'milo');
    await flow.send('我喜欢音乐');
    expect(flow.interests, contains('音乐'));
    await flow.start();
    await flow.notification(false);
    now = now.add(const Duration(seconds: 6));
    expect(flow.discoveryCount, 1);
    await flow.markRead(0);
    final restored = ExperienceController(store, clock: () => now);
    await restored.load();
    expect(restored.step, ExperienceStep.home);
    expect(restored.name, '小明');
    expect(restored.isRead(0), isTrue);
    expect(restored.messages.length, 2);
    await restored.start();
    now = now.add(const Duration(seconds: 5));
    expect(restored.discoveryCount, 2);
  });
  test('保存失败不推进，重试与重置可用', () async {
    final store = MemoryStore();
    final flow = ExperienceController(store);
    await flow.load();
    store.fail = true;
    await flow.setName('名字');
    expect(flow.step, ExperienceStep.welcome);
    expect(flow.error, isNotNull);
    store.fail = false;
    await flow.setName('名字');
    expect(flow.step, ExperienceStep.character);
    await flow.reset();
    expect(flow.name, isEmpty);
    expect(flow.hasTask, isFalse);
  });
}
