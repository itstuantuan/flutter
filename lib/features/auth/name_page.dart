import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'phone_login_artwork.dart';

class NamePage extends StatefulWidget {
  const NamePage({super.key, required this.onContinue, this.initialName = ''});
  final Future<void> Function(String name) onContinue;
  final String initialName;
  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  late final _name = TextEditingController(text: widget.initialName);
  bool _busy = false;
  String? _error;
  Future<void> _continue() async {
    if (_busy || _name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onContinue(_name.text.trim());
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF100621),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, bounds) {
          final media = MediaQuery.of(context);
          final width = math.min(
            bounds.maxWidth - media.padding.horizontal,
            420.0,
          );
          final available = bounds.maxHeight - media.viewInsets.bottom;
          final top = math.min(
            308.0,
            math.max(media.padding.top + 54, available - 260),
          );
          return Stack(
            children: [
              const Positioned.fill(child: PhoneLoginArtwork(codeStep: false)),
              Positioned(
                top: 0,
                bottom: media.viewInsets.bottom,
                left: (bounds.maxWidth - width) / 2,
                width: width,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    top,
                    16,
                    math.max(media.padding.bottom, 16),
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        label: '怎么称呼你比较好？',
                        child: Image.asset(
                          'assets/design/name_title.png',
                          width: 242.304,
                          height: 25.9,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '留下你的名字，以后我就知道怎么叫你啦。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: 1,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 23),
                      SizedBox(
                        height: 60,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.fill,
                                child: loginSvg(
                                  'name_field',
                                  width: 343,
                                  height: 60,
                                ),
                              ),
                            ),
                            Center(
                              child: TextField(
                                key: const ValueKey('login-name'),
                                controller: _name,
                                enabled: !_busy,
                                maxLength: 40,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.nickname],
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _continue(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '请输入你的名字',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF514762),
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 26,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _name.text.trim().isEmpty ? .24 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(104),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
                            ),
                          ),
                          child: TextButton(
                            key: const ValueKey('name-next'),
                            onPressed: _busy || _name.text.trim().isEmpty
                                ? null
                                : _continue,
                            style: TextButton.styleFrom(
                              overlayColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 58),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '继续',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFFB2DA)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
