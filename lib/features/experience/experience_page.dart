import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../notifications/push_service.dart';

import 'package:flutter/material.dart';

import '../auth/account_service.dart';
import '../auth/login_demo_page.dart';
import 'experience_controller.dart';
import 'experience_store.dart';

class ExperiencePage extends StatefulWidget {
  const ExperiencePage({super.key, this.controller});
  final ExperienceController? controller;
  @override
  State<ExperiencePage> createState() => _ExperiencePageState();
}

class _ExperiencePageState extends State<ExperiencePage>
    with WidgetsBindingObserver {
  late final ExperienceController flow;
  final input = TextEditingController();
  Timer? timer;
  final push = PushService();
  @override
  void initState() {
    super.initState();
    flow = widget.controller ?? ExperienceController(LocalExperienceStore());
    WidgetsBinding.instance.addObserver(this);
    flow.addListener(refresh);
    flow.load();
    push.addListener(refresh);
    push.initialize();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  bool demoOpening = false;
  void refresh() {
    if (!mounted) return;
    setState(() {});
    final notification = push.pendingNotification;
    if (kDebugMode &&
        !demoOpening &&
        notification?['source'] == 'local-demo' &&
        notification?['discoveryId'] == 'local-demo-discovery') {
      push.pendingNotification = null;
      demoOpening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('模拟发现详情')),
              body: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('给自己留十分钟听首歌', style: TextStyle(fontSize: 24)),
                      SizedBox(height: 16),
                      Text('这是一条固定的本地模拟发现。你已完成：安排通知 → 系统展示 → 点击 → 进入详情。'),
                      SizedBox(height: 16),
                      Text('无需登录或后端，仅验证前端交互；没有执行真实探索，也没有经过 APNs。'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        demoOpening = false;
        refresh();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    refresh();
    if (state == AppLifecycleState.resumed) push.refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    push.removeListener(refresh);
    push.dispose();
    WidgetsBinding.instance.removeObserver(this);
    flow.removeListener(refresh);
    if (widget.controller == null) flow.dispose();
    input.dispose();
    super.dispose();
  }

  Widget action(String label, Future<void> Function() onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FilledButton(
      onPressed: flow.busy ? null : onTap,
      child: Text(label),
    ),
  );
  Widget heading(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(body),
      const SizedBox(height: 24),
    ],
  );
  Widget chat() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('${flow.character.name}：你好，${flow.name}！最近有什么让你特别感兴趣的事？'),
      ...flow.messages.map(
        (m) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(m),
        ),
      ),
      TextField(
        controller: input,
        decoration: const InputDecoration(labelText: '输入消息（本版仅文字模拟）'),
      ),
      action('发送', () async {
        final text = input.text;
        await flow.send(text);
        if (flow.error == null) input.clear();
      }),
    ],
  );
  Future<void> detail(int index) async {
    await flow.markRead(index);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                flow.discoveryTitle(index),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(flow.discoveryBody(index)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  input.text = '聊聊「${flow.discoveryTitle(index)}」';
                  Navigator.pop(context);
                },
                child: const Text('带回聊天继续聊'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> content() {
    switch (flow.step) {
      case ExperienceStep.welcome:
        return [
          heading('欢迎来到 ViiTor', '这里生活着许多独特的 AI，它们有自己的性格、兴趣和故事，正在寻找属于自己的朋友。'),
          const Icon(Icons.graphic_eq, size: 64),
          const Text('旁白占位：尚未接入音频'),
          action(flow.muted ? '取消静音（模拟）' : '静音（模拟）', flow.toggleMute),
          action('Continue', () => flow.go(ExperienceStep.world)),
        ];
      case ExperienceStep.world:
        return [
          heading('探索世界，再回来分享', 'AI 不只是等待聊天。它们会探索世界、发现有趣的事、认识其他 AI，再回来与你分享故事。'),
          action('Meet your AI friend', () => flow.go(ExperienceStep.name)),
        ];
      case ExperienceStep.name:
        return [
          heading('你想让我如何称呼你？', '用文字输入名字，帮助 AI 准确称呼你。'),
          TextField(
            controller: input,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '你的名字'),
          ),
          action('继续', () async {
            await flow.setName(input.text);
            if (flow.step != ExperienceStep.name) input.clear();
          }),
        ];
      case ExperienceStep.character:
        return [
          heading('认识你的 AI', '模拟候选列表。暂用手动选择验证流程，每位用户只绑定一个 AI；最终获取方式待确认。'),
          ...demoCharacters.map(
            (c) => Card(
              child: ListTile(
                title: Text(c.name),
                subtitle: Text(c.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: flow.busy ? null : () => flow.bind(c.id),
              ),
            ),
          ),
        ];
      case ExperienceStep.chat:
        return [
          heading(
            '与 ${flow.character.name} 初次见面',
            '模拟回复；输入含音乐、旅行等兴趣词时会自动带入爱好选择。',
          ),
          chat(),
          action('去选择爱好 / 先去探索', () => flow.go(ExperienceStep.interests)),
        ];
      case ExperienceStep.interests:
        return [
          heading('你喜欢什么？', '聊天里提到的爱好已自动带入。可以调整，也可以直接开始。'),
          Wrap(
            spacing: 8,
            children: interestOptions
                .map(
                  (i) => FilterChip(
                    label: Text(i),
                    selected: flow.interests.contains(i),
                    onSelected: flow.busy
                        ? null
                        : (_) => flow.toggleInterest(i),
                  ),
                )
                .toList(),
          ),
          action('开始探索（爱好可选）', flow.start),
        ];
      case ExperienceStep.notification:
        return [
          heading('有新发现时，要告诉你吗？', '允许通知后，有真实发现时可以通知你。当前探索仍为模拟，后端推送尚未接通。'),
          if (push.error != null) Text(push.error!),
          if (push.authorization == 'denied')
            action('通知已关闭，前往系统设置', push.openSettings),
          action(push.busy ? '正在申请…' : '允许通知并继续', () async {
            if (push.busy) return;
            await push.request();
            if (push.error == null || !push.supported) {
              await flow.notification(push.allowed);
            }
          }),
          action('先不用', () => flow.notification(false)),
        ];
      case ExperienceStep.home:
        return [
          if (push.pendingNotification != null)
            const Text('已收到通知点击，真实发现详情等待后端接口接入。'),
          if (push.supported)
            Text(
              '通知：${push.authorization} · ${push.token == null ? '尚未获取 APNs token' : '已获取 APNs token'} · 尚未登记到后端',
            ),
          if (push.error != null) Text(push.error!),
          if (push.supported && push.allowed && push.token == null)
            action('重试注册推送', push.register),
          heading('${flow.character.name} 和你的日常', '继续聊天，或看看探索带回了什么。'),
          if (flow.discoveryCount < 2) const LinearProgressIndicator(),
          Text(
            flow.discoveryCount < 2
                ? '模拟探索中，可继续聊天或离开。约 5 秒首条发现，10 秒完整结果。'
                : '模拟探索已完成',
          ),
          ...List.generate(
            flow.discoveryCount,
            (i) => Card(
              child: ListTile(
                title: Text(flow.discoveryTitle(i)),
                subtitle: Text(flow.isRead(i) ? '已读' : '新发现 · 未读'),
                onTap: () => detail(i),
              ),
            ),
          ),
          if (flow.discoveryCount == 2) ...[
            const Text('下次计划：找一个不同视角的朋友交换推荐。（模拟计划，未自动执行）'),
            const Text('AI 社交：认识了一位新朋友；完整聊天查看入口待后续版本。'),
          ],
          const Divider(),
          chat(),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ViiTor · 流程验证'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'demoPush') {
              final scheduled = await push.scheduleDemo();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    scheduled
                        ? '已安排本地通知。现在回到桌面，约 5 秒后点击通知。'
                        : push.error ?? '仅支持 iOS 调试版。',
                  ),
                ),
              );
            } else if (value == 'copyPushToken') {
              if (!kDebugMode) return;
              await push.refresh();
              String message;
              final token = push.token;
              if (!push.supported) {
                message = 'APNs 测试仅支持 iOS。';
              } else if (token != null && token.isNotEmpty) {
                try {
                  await Clipboard.setData(ClipboardData(text: token));
                  message = '已复制 APNs token，可粘贴到苹果推送控制台。';
                } catch (_) {
                  message = '复制失败，请重试。';
                }
              } else {
                if (push.allowed) {
                  await push.register();
                } else {
                  await push.request();
                }
                message =
                    push.error ??
                    (push.allowed
                        ? '已请求 APNs 注册，请稍等后再次点击复制。'
                        : '请在系统设置中允许通知后重试。');
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            } else if (value == 'auth') {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LoginDemoPage(service: account),
                ),
              );
            } else {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('重置模拟体验？'),
                  content: const Text('仅清除本地模拟进度和聊天，不影响真实登录凭证。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('重置'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                input.clear();
                await flow.reset();
              }
            }
          },
          itemBuilder: (_) => const [
            if (kDebugMode)
              PopupMenuItem(value: 'demoPush', child: Text('5 秒后发送本地测试通知')),
            if (kDebugMode)
              PopupMenuItem(
                value: 'copyPushToken',
                child: Text('复制 APNs token'),
              ),
            PopupMenuItem(value: 'auth', child: Text('账号联调页')),
            PopupMenuItem(value: 'reset', child: Text('重置模拟体验')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '模拟环境 · 占位 UI · 与真实账号隔离',
            style: TextStyle(color: Colors.deepOrange),
          ),
          const SizedBox(height: 20),
          if (flow.error != null)
            Text(flow.error!, style: const TextStyle(color: Colors.red)),
          if (!flow.ready) action('加载 / 重试', flow.load) else ...content(),
        ],
      ),
    ),
  );
}
