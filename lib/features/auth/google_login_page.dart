import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../settings/privacy_policy_page.dart';
import '../settings/service_agreement_page.dart';
import 'account_service.dart';
import 'phone_login_artwork.dart';

/// Figma 551:3679; the account service owns credential exchange and persistence.
class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({
    super.key,
    required this.service,
    required this.onAuthenticated,
  });
  final AccountService service;
  final FutureOr<void> Function(AccountSession) onAuthenticated;

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  bool _busy = false;
  String? _error;
  CancelToken? _request;
  late final _terms = TapGestureRecognizer()..onTap = () => _policy(false);
  late final _privacy = TapGestureRecognizer()..onTap = () => _policy(true);

  void _policy(bool privacy) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            privacy ? const PrivacyPolicyPage() : const ServiceAgreementPage(),
      ),
    );
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _request = CancelToken();
      final session = await widget.service.googleLogin(cancelToken: _request);
      if (!mounted) return;
      await widget.onAuthenticated(session);
    } on GoogleLoginException catch (error) {
      if (mounted && !error.cancelled) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            AccountException e => e.message,
            DioException e => e.userMessage,
            StateError e => e.message,
            _ => '暂时无法完成，请稍后重试',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _request?.cancel('登录页面已关闭');
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A093A),
        body: LayoutBuilder(
          builder: (context, bounds) {
            final width = math.min(bounds.maxWidth, 420.0);
            final scale = width / 375;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(bounds.maxHeight, 812 * scale),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 238 * scale,
                          width: width,
                          height: 574 * scale,
                          child: Opacity(
                            opacity: .05,
                            child: _character(false),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: PhoneLoginArtwork(
                            codeStep: false,
                            google: true,
                          ),
                        ),
                        Positioned(
                          left: 245 * scale,
                          top: 492 * scale,
                          width: 76 * scale,
                          height: 72 * scale,
                          child: Transform.flip(
                            flipX: true,
                            child: _character(true),
                          ),
                        ),
                        Positioned(
                          left: 24 * scale,
                          top: 275 * scale,
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _logo(),
                                const SizedBox(height: 17),
                                const Text('Everyday chats', style: _headline),
                                const SizedBox(height: 13),
                                const Text(
                                  'fresh discoveries',
                                  style: _headline,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            32.5 * scale,
                            564 * scale,
                            32.5 * scale,
                            math.max(MediaQuery.paddingOf(context).bottom, 24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(104),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2EA5EF),
                                      Color(0xFFA43ADD),
                                    ],
                                  ),
                                ),
                                child: TextButton(
                                  key: const ValueKey('google-login'),
                                  onPressed: _busy ? null : _login,
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.fromHeight(52 * scale),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: loginSvg(
                                                'google_icon',
                                                width: 20,
                                                height: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Flexible(
                                              child: Text(
                                                'Sign in with Google',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text:
                                          '·By continuing, you agree to Pals ',
                                    ),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      recognizer: _terms,
                                      style: _link,
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy.',
                                      recognizer: _privacy,
                                      style: _link,
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 19.7 / 12,
                                  color: Color(0xD1FFFFFF),
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: AppText(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFFB2DA),
                                        fontSize: 13,
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
            );
          },
        ),
      ),
    ),
  );

  static const _headline = TextStyle(
    fontFamily: 'Newsreader',
    fontSize: 32,
    height: 1,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    color: Colors.white,
  );
  static const _link = TextStyle(color: Color(0xFF99A0FF));

  // Exported logo node preserves Figma's glow, unsupported by flutter_svg filters.
  Widget _logo() => Image.asset(
    'assets/login/google_logo.png',
    width: 69,
    height: 69,
    semanticLabel: 'Pals',
  );

  Widget _character(bool small) => LayoutBuilder(
    builder: (_, bounds) => ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: bounds.maxWidth * (small ? -.1192 : -.2149),
            top: 0,
            width: bounds.maxWidth * (small ? 1.1933 : 1.3237),
            height: bounds.maxHeight * (small ? 1.9252 : 1.2983),
            child: Image.asset(
              'assets/login/google_character.png',
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    ),
  );
}
