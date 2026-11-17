import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/network/api_client.dart';
import 'account_service.dart';
import 'phone_login_artwork.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.service,
    required this.onAuthenticated,
    this.preview = false,
    this.initialCodeStep = false,
    this.initialPhone = '',
    this.onOpenServiceAgreement,
    this.onOpenPrivacyPolicy,
  });
  final AccountService service;
  final FutureOr<void> Function(AccountSession) onAuthenticated;
  final bool preview, initialCodeStep;
  final String initialPhone;
  final VoidCallback? onOpenServiceAgreement, onOpenPrivacyPolicy;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  late bool _codeStep = widget.initialCodeStep;
  bool _agreed = false, _busy = false;
  String? _error;
  CancelToken? _request;
  Timer? _timer;
  String get _fullPhone => '86-${_phone.text}';
  bool get _validPhone => RegExp(r'^1[0-9]{10}$').hasMatch(_phone.text);
  bool get _enabled =>
      !_busy && (_codeStep ? _code.text.length == 6 : _validPhone && _agreed);
  int get _seconds =>
      widget.preview ? 0 : widget.service.resendSeconds(_fullPhone);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _codeStep) setState(() {});
    });
    if (_codeStep && !widget.preview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    }
  }

  String _message(Object error) {
    if (error is AccountException) return error.message;
    if (error is DioException) return error.userMessage;
    if (error is StateError) return error.message;
    if (error is ArgumentError) return '${error.message}';
    if (error is PlatformException) return '设备或安全存储暂不可用，请重试';
    return '暂时无法完成，请稍后重试';
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy || !_validPhone || (!resend && !_agreed)) return;
    if (resend && _seconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.preview && _seconds == 0) {
        _request = CancelToken();
        await widget.service.sendPhoneVerify(
          phone: _fullPhone,
          cancelToken: _request,
        );
      }
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _code.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (!_enabled) return;
    if (widget.preview) {
      setState(() => _error = '当前为界面预览，不会提交登录请求');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _request = CancelToken();
      final session = await widget.service.phoneVerifyLogin(
        phone: _fullPhone,
        code: _code.text,
        cancelToken: _request,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      FocusScope.of(context).unfocus();
      await widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToPhone() {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _codeStep = false;
      _code.clear();
      _error = null;
    });
  }

  void _openPolicy(bool privacy) {
    final open = privacy
        ? widget.onOpenPrivacyPolicy
        : widget.onOpenServiceAgreement;
    if (open != null) {
      open();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(privacy ? '隐私协议' : '服务协议'),
        content: const Text('协议内容将在正式上线前补充。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request?.cancel('登录页面已关闭');
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  static const _text = TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: 'PingFang SC',
    fontSize: 16,
    color: Colors.white,
    height: 1.2,
  );

  Widget _phoneInput() => SizedBox(
    height: 60,
    child: Stack(
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.fill,
            child: loginSvg('phone_field', width: 343, height: 60),
          ),
        ),
        Row(
          children: [
            const SizedBox(
              width: 62,
              child: Center(child: Text('+86', style: _text)),
            ),
            const SizedBox(width: 31),
            Expanded(
              child: TextField(
                key: const ValueKey('login-phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) {
                  if (_enabled) _sendCode();
                },
                style: _text,
                cursorColor: const Color(0xFFF44BE6),
                decoration: InputDecoration(
                  hintText: '请输入手机号',
                  hintStyle: _text.copyWith(color: const Color(0xFF52535A)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 16),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _codeInput() => SizedBox(
    height: 56,
    child: Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < 6; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      i < _code.text.length ? _code.text[i] : '',
                      style: _text.copyWith(fontSize: 24),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: TextField(
            key: const ValueKey('login-code'),
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _verify(),
            showCursor: false,
            enableInteractiveSelection: true,
            style: _text.copyWith(color: Colors.transparent),
            decoration: const InputDecoration(
              labelText: '六位短信验证码',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: TextStyle(color: Colors.transparent),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nextButton() => Semantics(
    button: true,
    enabled: _enabled,
    label: '下一步',
    child: ExcludeSemantics(
      child: Opacity(
        opacity: _codeStep || _enabled || _busy ? 1 : .24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(104),
            gradient: const LinearGradient(
              colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
            ),
          ),
          child: TextButton(
            key: const ValueKey('login-next'),
            onPressed: _enabled ? (_codeStep ? _verify : _sendCode) : null,
            style: TextButton.styleFrom(
              overlayColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 58),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              foregroundColor: Colors.white,
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
                : Text(
                    '下一步',
                    style: _text.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _agreements() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Semantics(
        checked: _agreed,
        label: '同意服务协议和隐私协议',
        child: InkWell(
          key: const ValueKey('login-agree'),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: _busy ? null : () => setState(() => _agreed = !_agreed),
          child: SizedBox(
            width: 28,
            height: 44,
            child: Center(
              child: _agreed
                  ? const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFFF44BE6),
                    )
                  : loginSvg('agreement_unchecked', width: 16, height: 16),
            ),
          ),
        ),
      ),
      Flexible(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '我已阅读并同意',
              style: _text.copyWith(
                fontSize: 12,
                color: const Color(0x8FFFFFFF),
              ),
            ),
            _policyLink('《服务协议》', false),
            Text(
              '和',
              style: _text.copyWith(
                fontSize: 12,
                color: const Color(0x8FFFFFFF),
              ),
            ),
            _policyLink('《隐私协议》', true),
          ],
        ),
      ),
    ],
  );

  Widget _policyLink(String text, bool privacy) => InkWell(
    onTap: () => _openPolicy(privacy),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: _text.copyWith(fontSize: 12, color: const Color(0x8FF44BE6)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: PopScope(
      canPop: !_codeStep && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _codeStep) _backToPhone();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF100621),
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, bounds) {
            final media = MediaQuery.of(context);
            final available = bounds.maxHeight - media.viewInsets.bottom;
            final width = math.min(
              bounds.maxWidth - media.padding.horizontal,
              420.0,
            );
            final top = math.min(
              _codeStep ? 213.0 : 308.0,
              math.max(
                media.padding.top + 54,
                available - (_codeStep ? 270 : 290) - 20,
              ),
            );
            return Stack(
              children: [
                Positioned.fill(child: PhoneLoginArtwork(codeStep: _codeStep)),
                Positioned(
                  top: 0,
                  bottom: media.viewInsets.bottom,
                  left: (bounds.maxWidth - width) / 2,
                  width: width,
                  child: SingleChildScrollView(
                    key: const ValueKey('login-content'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      top,
                      16,
                      math.max(media.padding.bottom, 16),
                    ),
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          Semantics(
                            header: true,
                            label: _codeStep ? '输入验证码' : '手机号登录',
                            child: loginSvg(
                              _codeStep ? 'otp_title' : 'phone_title',
                              width: 233,
                              height: 26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _codeStep
                                ? '验证码发送至+86 ${_phone.text}'
                                : '登录开始你的路程,Pals在等你',
                            textAlign: TextAlign.center,
                            style: _text.copyWith(
                              color: const Color(0xB3FFFFFF),
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: _codeStep ? 22 : 26),
                          _codeStep ? _codeInput() : _phoneInput(),
                          SizedBox(height: _codeStep ? 34 : 28),
                          _nextButton(),
                          if (_codeStep)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _busy ? null : _backToPhone,
                                  child: Text(
                                    '修改手机号',
                                    style: _text.copyWith(
                                      fontSize: 12,
                                      color: const Color(0x99FFFFFF),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy || _seconds > 0
                                      ? null
                                      : () => _sendCode(resend: true),
                                  child: Text(
                                    _seconds > 0 ? '${_seconds}s 后重发' : '重新发送',
                                    style: _text.copyWith(
                                      fontSize: 12,
                                      color: const Color(0xFFF44BE6),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            const SizedBox(height: 3),
                            _agreements(),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: _text.copyWith(
                                    fontSize: 13,
                                    color: const Color(0xFFFFB2DA),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_codeStep)
                  Positioned(
                    left: media.padding.left + 4,
                    top: media.padding.top + 8,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        key: const ValueKey('login-back'),
                        tooltip: '返回手机号输入',
                        onPressed: _busy ? null : _backToPhone,
                        padding: EdgeInsets.zero,
                        icon: SvgPicture.asset(
                          'assets/chat/back.svg',
                          width: 24,
                          height: 24,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
