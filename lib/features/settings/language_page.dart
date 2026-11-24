import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../shared/app_toast.dart';
import 'settings_widgets.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _saving = false;

  Future<void> _select(String code) async {
    if (_saving || AppLanguage.instance.locale.languageCode == code) return;
    setState(() => _saving = true);
    try {
      await AppLanguage.instance.select(code);
    } catch (_) {
      if (mounted) showAppToast(context, '保存语言失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppLanguage.instance,
    builder: (context, _) => SettingsScaffold(
      title: '语言切换',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Material(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _option('en', 'English'),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0x18FFFFFF),
                ),
                _option('zh', '简体中文'),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _option(String code, String label) {
    final selected = AppLanguage.instance.locale.languageCode == code;
    return Semantics(
      selected: selected,
      child: ListTile(
        enabled: !_saving,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: selected
            ? Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: settingsGradient,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              )
            : null,
        onTap: _saving ? null : () => _select(code),
      ),
    );
  }
}
