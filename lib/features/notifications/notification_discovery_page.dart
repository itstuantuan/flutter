import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/account_service.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_service.dart';
import '../chat/live_chat_page.dart';

class ExplorationNotification {
  const ExplorationNotification({
    required this.taskId,
    required this.sessionId,
    required this.notificationId,
  });
  final String taskId, sessionId, notificationId;

  static ExplorationNotification? parse(Map<String, String> value) {
    if (value['event'] != 'exploration_completed') return null;
    final task = value['taskId'],
        session = value['sessionId'],
        id = value['notificationId'];
    if ([
      task,
      session,
      id,
    ].any((e) => e == null || e.trim().isEmpty || e.length > 512)) {
      return null;
    }
    return ExplorationNotification(
      taskId: task!,
      sessionId: session!,
      notificationId: id!,
    );
  }
}

/// Show chat while resolving an authorized notification target.
class NotificationDiscoveryPage extends StatefulWidget {
  const NotificationDiscoveryPage({
    super.key,
    required this.notification,
    required this.account,
    required this.session,
    required this.service,
    this.onDisplayed,
  });
  final ExplorationNotification notification;
  final AccountService account;
  final AccountSession session;
  final ChatService service;
  final Future<void> Function(String taskId)? onDisplayed;

  @override
  State<NotificationDiscoveryPage> createState() =>
      _NotificationDiscoveryPageState();
}

class _NotificationDiscoveryPageState extends State<NotificationDiscoveryPage> {
  final _cancel = CancelToken();
  bool _displayed = false;
  bool get _currentAccount =>
      !_cancel.isCancelled && identical(widget.account.session, widget.session);

  @override
  void initState() {
    super.initState();
    widget.account.beforeLogout.add(_closeForLogout);
  }

  Future<void> _closeForLogout() async {
    _cancel.cancel('Notification account signed out');
    if (mounted) setState(() {});
  }

  Future<ChatController> _load() async {
    try {
      if (!_currentAccount) throw const ChatException('账号已变化，请返回后重新打开通知。');
      final notification = widget.notification;
      final result = await widget.service.request(
        '/sessions/${Uri.encodeComponent(notification.sessionId)}/messages/locate/${Uri.encodeComponent(notification.taskId)}',
        cancelToken: _cancel,
      );
      if (!_currentAccount) throw const ChatException('账号已变化，请返回后重新打开通知。');
      if (result['sessionId'] != notification.sessionId ||
          result['turns'] is! List ||
          result['anchorTurnId'] is! int) {
        throw const ChatException('无法确认这条发现，请重试。');
      }
      final anchorId = result['anchorTurnId'] as int;
      final turns = (result['turns'] as List).whereType<Map>().toList();
      final anchor = turns.where((turn) => turn['id'] == anchorId).firstOrNull;
      if (anchor == null) {
        throw const ChatException('对应发现尚未加载，请重试。');
      }
      for (final turn in [
        if (anchor['referenceTaskId'] == null ||
            anchor['referenceTaskId'] == notification.taskId)
          anchor,
        ...turns.where(
          (turn) =>
              turn['id'] != anchorId &&
              turn['referenceTaskId'] == notification.taskId,
        ),
      ]) {
        if (!{'discovery', 'explore'}.contains(turn['messageType']) ||
            turn['status'] != 'completed' ||
            turn['id'] is! int) {
          continue;
        }
        final exploration = turn['exploration'];
        final raw = exploration is Map ? exploration['cards'] : null;
        if (raw is! List) continue;
        for (final card in raw.whereType<Map>()) {
          final id = card['materialId'];
          if (id is! String ||
              id.isEmpty ||
              ![
                card['content'],
                card['summary'],
              ].whereType<String>().any((text) => text.trim().isNotEmpty)) {
            continue;
          }
          return ChatController(
              widget.service,
              displayName: widget.session.nick,
              sessionId: notification.sessionId,
            )
            ..merge(result)
            ..setLocation(
              turn['id'] as int,
              taskId: notification.taskId,
              materialId: id,
            );
        }
      }
      throw const ChatException('这条通知没有可展示的发现。');
    } on DioException catch (e) {
      throw ChatException(switch (e.response?.statusCode) {
        401 => '登录已过期，请重新登录后查看。',
        403 || 404 => '这条发现不存在，或不属于当前账号。',
        _ => '暂时无法加载发现，请检查网络后重试。',
      });
    }
  }

  Future<void> _acknowledge(String taskId) async {
    if (!_currentAccount ||
        _displayed ||
        taskId != widget.notification.taskId ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _displayed = true;
    try {
      await widget.onDisplayed?.call(taskId);
    } catch (_) {
      // The exploration controller keeps its acknowledgement retry ledger.
    }
  }

  @override
  void dispose() {
    widget.account.beforeLogout.remove(_closeForLogout);
    _cancel.cancel('Notification page closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LiveChatPage(
    key: ValueKey(_currentAccount),
    accountService: widget.account,
    createController: _load,
    onExit: () => Navigator.of(context).pop(),
    onExplore: () {},
    onDiscoveryVisible: _acknowledge,
  );
}
