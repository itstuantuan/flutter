import '../../core/localization/app_localizations.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/app_toast.dart';
import 'settings_store.dart';
import 'settings_widgets.dart';

const feedbackFunctions = ['首页', '逛一逛圈子', '对话聊天'];
const feedbackTypes = [
  '识别不准确',
  '翻译不准确',
  '速度太慢',
  '网络错误',
  '翻译不出结果',
  '无法播放声音',
  '其他',
];

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.uid,
    this.store = const SettingsStore(),
  });
  final String uid;
  final SettingsStore store;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _description = TextEditingController(),
      _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _function, _type;
  List<Uint8List> _images = [];
  bool _saving = false, _picking = false, _loading = true;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final draft = await widget.store.feedback(widget.uid);
      if (!mounted || draft == null) return;
      _description.text = draft['description'] as String? ?? '';
      _email.text = draft['email'] as String? ?? '';
      _function = draft['function'] as String?;
      _type = draft['type'] as String?;
      _images = (draft['images'] as List? ?? [])
          .cast<String>()
          .map(base64Decode)
          .toList();
    } catch (_) {
      if (mounted) _notice('未能读取已保存的反馈');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _email.dispose();
    super.dispose();
  }

  void _notice(String message) => showAppToast(context, message);
  Future<void> _select(bool function) async {
    FocusScope.of(context).unfocus();
    final selected = await showSettingsChoices(
      context,
      title: function ? '功能' : '问题类型',
      options: function ? feedbackFunctions : feedbackTypes,
      selected: function ? _function : _type,
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (function) {
        _function = selected;
      } else {
        _type = selected;
      }
    });
  }

  Future<void> _pick() async {
    if (_images.length >= 3 || _picking) return;
    setState(() => _picking = true);
    try {
      final remaining = 3 - _images.length;
      final picker = ImagePicker();
      final List<XFile> files;
      if (remaining == 1) {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage(
          limit: remaining,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 80,
          requestFullMetadata: false,
        );
      }
      final images = <Uint8List>[];
      for (final file in files.take(remaining)) {
        final data = await file.readAsBytes();
        if (data.length > 5 * 1024 * 1024) throw StateError('截图过大');
        images.add(data);
      }
      if (mounted) setState(() => _images.addAll(images));
    } catch (_) {
      if (mounted) _notice('无法读取截图，请检查相册权限或选择小于 5MB 的图片');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveFeedback(widget.uid, {
        'function': _function,
        'type': _type,
        'description': _description.text.trim(),
        'email': _email.text.trim(),
        'images': _images.map(base64Encode).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) _notice('反馈已保存到本机，暂未发送；反馈服务接入后可提交');
    } catch (_) {
      if (mounted) _notice('保存失败，内容已保留，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text, {bool required = false}) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: translate(context, text)),
        if (required)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
      ],
    ),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
      height: 23 / 15,
    ),
  );
  Widget _choice(bool function) => FormField<String>(
    validator: (_) => (function ? _function : _type) == null
        ? translate(context, function ? '请选择功能' : '请选择问题类型')
        : null,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _saving ? null : () => _select(function),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: field.hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE5E7EB).withValues(alpha: .1),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    (function ? _function : _type) ??
                        (function ? '请选择功能' : '请选择问题'),
                    style: TextStyle(
                      color: (function ? _function : _type) == null
                          ? const Color(0xFF6B7280)
                          : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                settingsIcon('field_chevron', 16),
              ],
            ),
          ),
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppText(
              field.errorText!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),
      ],
    ),
  );
  InputDecoration _decoration(String hint, {Color? fill, int radius = 16}) =>
      InputDecoration(
        hintText: translate(context, hint),
        filled: true,
        fillColor: fill ?? Colors.white.withValues(alpha: .06),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.toDouble()),
          borderSide: BorderSide(
            color: const Color(0xFFE5E7EB).withValues(alpha: .1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.toDouble()),
          borderSide: BorderSide(
            color: const Color(0xFFE5E7EB).withValues(alpha: .1),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: '反馈问题',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('遇到问题的功能', required: true),
                    const SizedBox(height: 8),
                    _choice(true),
                    const SizedBox(height: 16),
                    _label('问题类型', required: true),
                    const SizedBox(height: 8),
                    _choice(false),
                    const SizedBox(height: 16),
                    _label('详细描述', required: true),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 118,
                      child: Stack(
                        children: [
                          TextFormField(
                            controller: _description,
                            maxLength: 500,
                            maxLines: null,
                            expands: true,
                            enabled: !_saving,
                            textAlignVertical: TextAlignVertical.top,
                            onChanged: (_) => setState(() {}),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(500),
                            ],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? translate(context, '请填写详细描述')
                                : null,
                            decoration:
                                _decoration(
                                  '请具体描述您遇到的问题，包括使用场景、识别/翻译语种等。',
                                  fill: settingsBackground,
                                  radius: 12,
                                ).copyWith(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    34,
                                  ),
                                ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 12,
                            child: IgnorePointer(
                              child: Text(
                                '${_description.text.characters.length}/500',
                                style: const TextStyle(
                                  color: settingsMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: translate(context, '上传截图  '),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '(${_images.length}/3)',
                            style: const TextStyle(color: Color(0xFF898D96)),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (index, data) in _images.indexed)
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      data,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: InkWell(
                                    onTap: _saving
                                        ? null
                                        : () => setState(
                                            () => _images.removeAt(index),
                                          ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_images.length < 3)
                          Semantics(
                            button: true,
                            label: translate(context, '上传截图'),
                            child: InkWell(
                              onTap: _saving || _picking ? null : _pick,
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                painter: _DashedBorder(),
                                child: SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: Center(
                                    child: _picking
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : settingsIcon('plus', 24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('邮箱'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _decoration('我们会尽快处理您的反馈').copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) =>
                          value != null &&
                              value.trim().isNotEmpty &&
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())
                          ? translate(context, '请输入有效邮箱')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SettingsGradientButton(
                      label: _saving ? '保存中…' : '提交反馈',
                      onPressed: _saving || _picking ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFFF5F1FF).withValues(alpha: .06),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = const Color(0xFF6F95FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(metric.extractPath(offset, offset + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
