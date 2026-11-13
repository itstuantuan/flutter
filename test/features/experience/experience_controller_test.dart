import 'package:flutter_test/flutter_test.dart';
import 'package:bots/features/chat/chat_message.dart';
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
  test('文字和真实录音按顺序保存，重开恢复且不伪造语音回复', () async {
    final store = MemoryStore();
    final flow = ExperienceController(store);
    await flow.load();
    await flow.send('你好');
    const clip = VoiceClip(
      path: '/tmp/saved.m4a',
      duration: Duration(seconds: 3),
    );
    expect(await flow.saveVoice(clip), isTrue);
    await flow.send('下一条');
    final restored = ExperienceController(store);
    await restored.load();
    expect(restored.chatMessages, hasLength(5));
    expect(restored.chatMessages[2].voice?.path, clip.path);
    expect(restored.chatMessages[2].voice?.duration, clip.duration);
    expect(restored.chatMessages[3].text, '下一条');
    store.fail = true;
    expect(await flow.saveVoice(clip), isFalse);
    expect(flow.chatMessages, hasLength(5));
    flow.dispose();
    restored.dispose();
  });

  test('新增引导页按固定 ID 保存恢复，完成只推进模拟流程', () async {
    final store = MemoryStore();
    final flow = ExperienceController(store);
    await flow.load();
    await flow.advanceOnboarding('new-feature');
    final restored = ExperienceController(store);
    await restored.load();
    expect(restored.onboardingPageId, 'new-feature');
    expect(restored.step, ExperienceStep.welcome);
    await restored.advanceOnboarding(null);
    expect(restored.step, ExperienceStep.name);
    expect(restored.onboardingPageId, isNull);
    expect(store.data?['onboardingCompleted'], isNull);
    flow.dispose();
    restored.dispose();
  });

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
