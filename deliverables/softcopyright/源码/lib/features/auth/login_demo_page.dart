import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import 'account_service.dart';
import 'auth_debug_log.dart';

class LoginDemoPage extends StatefulWidget {
  const LoginDemoPage({super.key, required this.service});

  final AccountService service;

  @override
  State<LoginDemoPage> createState() => _LoginDemoPageState();
}

class _LoginDemoPageState extends State<LoginDemoPage> {
  final _country = TextEditingController(text: '86');
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  CancelToken? _request;
  bool _busy = true;
  String _message = '正在读取本地会话…';
  bool _failed = false;

  String get _fullPhone => '${_country.text.trim()}-${_phone.text.trim()}';

  @override
  void initState() {
    super.initState();
    _country.addListener(_refresh);
    _phone.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _restore();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _run(
    Future<String> Function() action, {
    String operation = '退出会话',
  }) async {
    AuthDebugLog.event('$operation START');
    setState(() {
      _busy = true;
      _failed = false;
      _message = '处理中…';
    });
    try {
      final message = await action();
      AuthDebugLog.event('$operation OK');
      if (mounted) setState(() => _message = message);
    } catch (error, stack) {
      AuthDebugLog.error(operation, error, stack);
      if (mounted) {
        setState(() {
          _failed = !(error is GoogleLoginException && error.cancelled);
          _message = _errorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is GoogleLoginException) return error.message;
    if (error is AccountException) return '${error.message}（${error.status}）';
    if (error is ArgumentError) return '${error.message}';
    if (error is StateError) return error.message;
    if (error is ApiDecodeException) return error.message;
    if (error is PlatformException) return '设备信息或安全存储读取失败，请在设备解锁后重试';
    if (error is DioException) {
      if (error.error is StateError) return (error.error as StateError).message;
      return error.userMessage;
    }
    return '操作失败，请稍后重试';
  }

  Future<void> _restore() => _run(() async {
    final session = await widget.service.restoreSession();
    return session == null ? '尚无本地会话，请输入手机号测试。' : '已恢复本地会话，尚未验证服务端有效性。';
  }, operation: '恢复会话');

  Future<void> _send() => _run(() async {
    _request = CancelToken();
    await widget.service.sendPhoneVerify(
      phone: _fullPhone,
      cancelToken: _request,
    );
    return '验证码已发送，请查看手机短信。';
  }, operation: '发送验证码');

  Future<void> _login() => _run(() async {
    FocusScope.of(context).unfocus();
    _request = CancelToken();
    await widget.service.phoneVerifyLogin(
      phone: _fullPhone,
      code: _code.text,
      cancelToken: _request,
    );
    _code.clear();
    return '登录成功，用户信息和 token 已保存。';
  }, operation: '手机验证码登录');

  Future<void> _googleLogin() => _run(() async {
    FocusScope.of(context).unfocus();
    _request = CancelToken();
    await widget.service.googleLogin(cancelToken: _request);
    _code.clear();
    return 'Google 登录成功，账号系统会话已保存。';
  }, operation: 'Google 登录');

  @override
  void dispose() {
    _timer?.cancel();
    _request?.cancel('测试页已关闭');
    _country.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final session = service.session;
    final seconds = service.resendSeconds(_fullPhone);
    final signer = service.client.signer;
    return Scaffold(
      appBar: AppBar(title: const Text('账号登录测试')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'diagnostics-v2 · ${kDebugMode
                      ? "Debug"
                      : kProfileMode
                      ? "Profile"
                      : "Release"}',
                  style: TextStyle(fontSize: 12),
                ),

                Text(
                  '账号接口 Demo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '产品：${signer?.product ?? "未配置"} · 平台：${signer?.platform ?? "未配置"}',
                ),
                const SizedBox(height: 4),
                Text(
                  service.client.dio.options.baseUrl,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _busy ? null : _googleLogin,
                  child: const Text('使用 Google 账号登录'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('或使用手机验证码')),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _country,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '国家区号',
                          prefixText: '+',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          hintText: '输入测试手机号',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy || seconds > 0 ? null : _send,
                  child: Text(seconds > 0 ? '${seconds}s 后重新发送' : '发送验证码'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '短信验证码'),
                  onSubmitted: (_) {
                    if (!_busy) _login();
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: const Text('登录并保存会话'),
                ),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _failed
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (session != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前会话',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            'UID：${session.uid}\n昵称：${session.nick}\n手机号：${session.phone.isEmpty ? '未绑定' : session.phone}\n邮箱：${session.email.isEmpty ? '未返回' : session.email}\n产品 / 平台：${session.product} / ${session.platform}\n首次注册：${session.isNewUser ? "是" : "否"}',
                          ),
                          const SizedBox(height: 8),
                          const Text('Token 已保存（不显示完整凭证）'),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('读取本地会话'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await service.logout();
                          _code.clear();
                          return '本地会话已清除。';
                        }),
                  child: const Text('退出并清除本地会话'),
                ),
                const SizedBox(height: 16),
                if (kDebugMode)
                  ValueListenableBuilder<List<String>>(
                    valueListenable: AuthDebugLog.entries,
                    builder: (context, entries, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('诊断日志（最近 80 条）'),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      AuthDebugLog.event('日志输出测试 OK'),
                                  child: const Text('测试日志输出'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: entries.join('\n')),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('诊断日志已复制')),
                                    );
                                  },
                                  child: const Text('复制日志'),
                                ),
                              ],
                            ),
                            SelectableText(
                              entries.isEmpty ? '暂无记录' : entries.join('\n'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Text(
                  '若控制台没有日志，可在本页复制诊断日志。',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  '会发送真实短信。同一手机号间隔至少 60 秒，每天最多 3 次。\nip 默认为空；移动端 uuid 自动从设备读取。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
