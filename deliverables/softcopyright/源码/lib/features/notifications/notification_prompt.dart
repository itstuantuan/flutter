import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'push_service.dart';

class NotificationPromptStore {
  const NotificationPromptStore();
  static const _key = 'bots.notification-prompt.v1';
  static const _storage = FlutterSecureStorage();
  Future<bool> wasShown() async => await _storage.read(key: _key) == 'true';
  Future<void> markShown() => _storage.write(key: _key, value: 'true');
  Future<void> clear() => _storage.delete(key: _key);
}

/// Only mounted on the home screen; never requests OS permission automatically.
class HomeNotificationPrompt extends StatefulWidget {
  const HomeNotificationPrompt({
    super.key,
    required this.push,
    required this.child,
    this.store = const NotificationPromptStore(),
  });
  final PushService push;
  final NotificationPromptStore store;
  final Widget child;
  @override
  State<HomeNotificationPrompt> createState() => _HomeNotificationPromptState();
}

class _HomeNotificationPromptState extends State<HomeNotificationPrompt> {
  bool _checking = false, _done = false;
  bool get _visible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _check() async {
    if (_checking || _done || !_visible || !widget.push.supported) return;
    _checking = true;
    try {
      if (await widget.store.wasShown()) {
        _done = true;
        return;
      }
      if (!_visible) return;
      await widget.push.refresh();
      if (!_visible || widget.push.error != null) return;
      if (widget.push.allowed) {
        _done = true;
        return;
      }
      await widget.store.markShown();
      if (!_visible) {
        await widget.store.clear();
        return;
      }
      _done = true;
      if (!mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xCC000000),
        builder: (_) => const NotificationPermissionDialog(),
      );
      if (!mounted || allow != true) return;
      // Refresh after the choice, in case permission changed in Settings.
      await widget.push.refresh();
      if (!mounted) return;
      if (widget.push.allowed) return;
      if (widget.push.error == null) {
        if (widget.push.authorization == 'denied') {
          await widget.push.openSettings();
        } else {
          await widget.push.request();
        }
      }
      if (mounted && widget.push.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.push.error!)));
      }
    } catch (_) {
      // A failed status/storage read must not block home or consume the prompt.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
    return widget.child;
  }
}

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 322),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 11.95, sigmaY: 11.95),
          child: ColoredBox(
            color: const Color(0xFF2F283B),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '开启 Pals 消息通知',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 18,
                      height: 25 / 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '有趣的新发现、新故事和重要消息，Pals 都会及时告诉您。',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 14,
                      height: 20 / 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 13,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xCFFFFFFF),
                            minimumSize: const Size(68, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: const Text(
                            '不允许',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/notifications/divider.svg',
                          width: .5,
                          height: 19.5,
                          excludeFromSemantics: true,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6953D4), Color(0xFF892DB7)],
                            ),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 19,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              '允许',
                              style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
