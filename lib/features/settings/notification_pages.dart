import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import 'settings_widgets.dart';

class SystemMessage {
  const SystemMessage({
    required this.title,
    required this.body,
    required this.time,
    this.sender = 'Viitor正在逛',
  });
  final String title, body, time, sender;
}

const designSystemMessage = SystemMessage(
  title: '功能更新 4.0.2 版本！',
  time: '2026-09-09 15:21',
  body:
      'ViiTor AI 新版本已上线\n本次主要优化了视频翻译的配置与操作流程，让常用功能更容易理解和使用。\n更新内容：\n'
      '• 优化视频翻译配置结构，常用设置前置展示\n• 支持快速选择需要翻译的内容：配音 / 字幕\n'
      '• 优化翻译语种选择，操作路径更清晰\n• 新增原字幕擦除快捷设置\n'
      '• 低频配置统一收纳至「高级设置」，减少页面信息干扰\n• 优化页面引导与交互细节，降低首次使用门槛',
);

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.messages = const []});
  final List<SystemMessage> messages;
  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: '系统通知',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (messages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: AppText('暂无系统通知', style: TextStyle(color: settingsMuted)),
            ),
          ),
        for (final message in messages)
          Card(
            color: Colors.white.withValues(alpha: .06),
            child: ListTile(
              title: Text(
                message.title,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                message.time,
                style: const TextStyle(color: settingsMuted),
              ),
              trailing: settingsIcon('profile_chevron', 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MessageDetailPage(message: message),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class MessageDetailPage extends StatelessWidget {
  const MessageDetailPage({super.key, required this.message});
  final SystemMessage message;
  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: message.sender,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 24),
      children: [
        Text(
          message.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.48,
          ),
        ),
        const SizedBox(height: 11.4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            message.body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 21.616 / 14,
            ),
          ),
        ),
        const SizedBox(height: 11.4),
        Text(
          message.time,
          style: const TextStyle(color: settingsMuted, fontSize: 14),
        ),
      ],
    ),
  );
}
