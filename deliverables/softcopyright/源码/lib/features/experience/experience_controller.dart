import 'package:flutter/foundation.dart';

import 'experience_store.dart';
import '../chat/chat_message.dart';

enum ExperienceStep {
  welcome,
  world,
  name,
  character,
  chat,
  interests,
  notification,
  home,
}

class DemoCharacter {
  const DemoCharacter(this.id, this.name, this.description);
  final String id, name, description;
}

const demoCharacters = [
  DemoCharacter('nova', 'Nova', '好奇、活泼，喜欢音乐和旅行'),
  DemoCharacter('milo', 'Milo', '温和、细腻，喜欢阅读和电影'),
  DemoCharacter('lumi', 'Lumi', '富有想象力，喜欢游戏和艺术'),
];
const interestOptions = ['音乐', '旅行', '阅读', '电影', '游戏', '艺术'];

class ExperienceController extends ChangeNotifier {
  ExperienceController(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ExperienceStore store;
  final DateTime Function() clock;
  Map<String, dynamic> _data = {'step': 'welcome'};
  bool ready = false, busy = false;
  String? error;
  ExperienceStep get step =>
      ExperienceStep.values.byName(_data['step'] as String);
  String? get onboardingPageId =>
      _data['onboardingPageId'] as String? ??
      (step == ExperienceStep.world ? 'world' : null);

  Future<void> advanceOnboarding(String? nextPageId) => _save({
    'onboardingPageId': nextPageId,
    // Keep compatibility with existing mock-flow steps and old saved progress.
    'step': nextPageId == null
        ? 'name'
        : nextPageId == 'world'
        ? 'world'
        : 'welcome',
  });

  String get name => _data['name'] as String? ?? '';
  DemoCharacter get character => demoCharacters.firstWhere(
    (c) => c.id == _data['character'],
    orElse: () => demoCharacters.first,
  );
  List<String> get interests =>
      List<String>.from(_data['interests'] as List? ?? []);
  List<String> get messages =>
      List<String>.from(_data['messages'] as List? ?? []);
  List<ChatMessage> get chatMessages {
    final saved = _data['chatMessages'];
    return saved is List
        ? saved
              .map(
                (entry) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList()
        : messages.map(ChatMessage.fromStored).toList();
  }

  Future<bool> saveVoice(VoiceClip clip) async {
    if (busy || clip.ephemeral) return false;
    await _save({
      'chatMessages': [
        ...chatMessages.map((message) => message.toJson()),
        ChatMessage('', isUser: true, voice: clip).toJson(),
      ],
    });
    return error == null;
  }

  bool get muted => _data['muted'] == true;
  bool get hasTask => _data['startedAt'] != null;
  int get elapsed => hasTask
      ? clock()
            .difference(DateTime.parse(_data['startedAt'] as String))
            .inSeconds
      : 0;
  int get discoveryCount => !hasTask || elapsed < 5
      ? 0
      : elapsed < 10
      ? 1
      : 2;
  bool isRead(int index) => (_data['read'] as List? ?? []).contains(index);
  String discoveryTitle(int index) => index == 0
      ? '${interests.isEmpty ? '音乐' : interests.first}：一个值得尝试的小灵感'
      : '${character.name} 认识了新朋友';
  String discoveryBody(int index) => index == 0
      ? '模拟发现：为自己留出十分钟，挑选一个喜欢的作品，记录最打动你的地方。这个内容用于验证详情与追问流程，并非实时搜索结果。'
      : '模拟社交经历：${character.name} 与另一位 AI 交流了各自的兴趣，约好下次交换推荐。完整 AI 对话查看暂未开放。';

  Future<void> load() async {
    try {
      final saved = await store.read();
      if (saved != null) {
        ExperienceStep.values.byName(saved['step'] as String);
        if (saved['startedAt'] != null) {
          DateTime.parse(saved['startedAt'] as String);
        }
        for (final key in ['interests', 'messages']) {
          List<String>.from(saved[key] as List? ?? []);
        }
        _data = saved;
      }
      ready = true;
      error = null;
    } catch (_) {
      error = '无法恢复模拟进度，请重试。';
    }
    notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    final next = {..._data, ...changes};
    try {
      await store.write(next);
      _data = next;
    } catch (_) {
      error = '保存失败，请重试；当前进度未推进。';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> go(ExperienceStep next) => _save({'step': next.name});
  Future<void> setName(String value) async {
    if (value.trim().isEmpty) return;
    await _save({'name': value.trim(), 'step': 'character'});
  }

  Future<void> bind(String id) async {
    if (_data['character'] != null || !demoCharacters.any((c) => c.id == id)) {
      return;
    }
    await _save({'character': id, 'step': 'chat'});
  }

  Future<void> saveInterests(List<String> values) =>
      _save({'interests': values.toSet().toList()});

  Future<void> toggleMute() => _save({'muted': !muted});
  Future<void> toggleInterest(String value) {
    final selected = interests;
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    return _save({'interests': selected});
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final detected = {...interests, ...interestOptions.where(text.contains)};
    await _save({
      'interests': detected.toList(),
      'chatMessages': [
        ...chatMessages.map((message) => message.toJson()),
        ChatMessage(text.trim(), isUser: true).toJson(),
        const ChatMessage('谢谢你分享！我记住了，我们可以围绕这些兴趣一起探索。（模拟回复）').toJson(),
      ],
      'messages': [
        ...messages,
        '你：${text.trim()}',
        '${character.name}：谢谢你分享！我记住了，我们可以围绕这些兴趣一起探索。（模拟回复）',
      ],
    });
  }

  Future<void> start() async {
    if (hasTask) {
      await go(ExperienceStep.home);
      return;
    }
    await _save({
      'startedAt': clock().toUtc().toIso8601String(),
      'step': 'notification',
    });
  }

  Future<void> notification(bool accepted) => _save({
    'notification': accepted ? 'systemAuthorized' : 'skipped',
    'step': 'home',
    'onboardingCompleted': true,
  });
  Future<void> markRead(int index) => _save({
    'read': {...List<int>.from(_data['read'] as List? ?? []), index}.toList(),
  });
  Future<void> reset() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await store.write({'step': 'welcome'});
      _data = {'step': 'welcome'};
      ready = true;
      error = null;
    } catch (_) {
      error = '重置失败，请重试。';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
