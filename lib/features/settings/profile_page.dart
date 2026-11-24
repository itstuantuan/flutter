import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/app_toast.dart';
import 'settings_store.dart';
import 'settings_widgets.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.bytes, this.url, this.size = 100});
  final Uint8List? bytes;
  final String? url;
  final double size;
  Widget _fallback() => ClipRect(
    child: OverflowBox(
      maxWidth: size * 2.5,
      maxHeight: size * 2.5,
      alignment: const Alignment(.021, .237),
      child: Image.asset(
        'assets/sidebar/profile_avatar.png',
        width: size * 2.5,
        height: size * 2.5,
        fit: BoxFit.fill,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: bytes != null
          ? Image.memory(bytes!, fit: BoxFit.cover)
          : url != null && url!.startsWith('http')
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => _fallback(),
            )
          : _fallback(),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.name,
    required this.uid,
    this.avatar,
    this.avatarUrl,
    required this.onSave,
    required this.onLogout,
  });
  final String name, uid;
  final Uint8List? avatar;
  final String? avatarUrl;
  final Future<void> Function(LocalUserProfile) onSave;
  final Future<void> Function() onLogout;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _name = widget.name;
  late Uint8List? _avatar = widget.avatar;
  bool _busy = false;
  void _notice(String text) => showAppToast(context, text);
  Future<void> _editName() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EditNamePage(
          name: _name,
          onSave: (name) async {
            await widget.onSave(LocalUserProfile(name: name, avatar: _avatar));
            if (mounted) setState(() => _name = name);
          },
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final source = await showSettingsChoices(
      context,
      title: '更换头像',
      options: ['拍照', '从相册中选择'],
      grouped: true,
    );
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source == '拍照' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError('图片过大');
      await widget.onSave(LocalUserProfile(name: _name, avatar: bytes));
      if (mounted) setState(() => _avatar = bytes);
    } catch (_) {
      if (mounted) _notice('无法更换头像，请检查相机或相册权限后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF474451),
        title: const AppText('退出登录', style: TextStyle(color: Colors.white)),
        content: const AppText(
          '确定退出当前账号吗？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText(
              '退出登录',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _logout();
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) _notice('退出失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: '编辑资料',
    child: LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    label: translate(context, '更换头像'),
                    child: InkWell(
                      onTap: _busy ? null : _changeAvatar,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          children: [
                            ProfileAvatar(
                              bytes: _avatar,
                              url: widget.avatarUrl,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF222222),
                                  shape: BoxShape.circle,
                                ),
                                child: settingsIcon('camera', 18),
                              ),
                            ),
                            if (_busy)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 42),
                  Material(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _busy ? null : _editName,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 56),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: .08),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const AppText(
                                    '昵称',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _name,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  settingsIcon('profile_chevron', 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.uid),
                            );
                            if (mounted) _notice('UID 已复制');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'ViiTor UID',
                                      style: TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.uid,
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  settingsIcon('copy', 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: (constraints.maxHeight * .36).clamp(70, 184),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8E8ED)
                              .withValues(alpha: .12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: const Color(0xFFEF4444)
                              .withValues(alpha: .71),
                        ),
                        onPressed: _busy ? null : _confirmLogout,
                        child: const AppText(
                          '退出登录',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 28),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    minimumSize: const Size(112, 48),
                  ),
                  onPressed: _busy ? null : _logout,
                  child: const AppText('注销账号', style: TextStyle(fontSize: 15)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EditNamePage extends StatefulWidget {
  const EditNamePage({super.key, required this.name, required this.onSave});
  final String name;
  final Future<void> Function(String) onSave;
  @override
  State<EditNamePage> createState() => _EditNamePageState();
}

class _EditNamePageState extends State<EditNamePage> {
  late final _input = TextEditingController(text: widget.name);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _input.text.trim();
    if (value.isEmpty || value.characters.length > 7) {
      setState(() => _error = '请设置 1-7 个字符');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingsScaffold(
      title: '编辑名字',
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: AppText(
            _busy ? '保存中' : '保存',
            style: const TextStyle(color: Color(0xFF73B5EE), fontSize: 14),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_busy,
                    maxLength: 7,
                    inputFormatters: [LengthLimitingTextInputFormatter(7)],
                    onChanged: (_) => setState(() => _error = null),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                Text(
                  '${_input.text.characters.length}/7',
                  style: const TextStyle(color: settingsMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppText(
            _error ?? '请设置 1-7 个字符',
            style: TextStyle(
              color: _error == null ? settingsMuted : const Color(0xFFEF4444),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
