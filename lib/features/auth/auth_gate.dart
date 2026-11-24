import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../experience/experience_page.dart';
import '../chat/chat_service.dart';
import 'account_service.dart';
import 'phone_login_page.dart';
import 'google_login_page.dart';
import 'name_page.dart';
import 'startup_profile_store.dart';
import '../onboarding/onboarding_flow.dart';

/// Restores local credentials before choosing the login or experience UI.
/// Server-side token validation remains the responsibility of protected APIs.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.service,
    this.experienceBuilder,
    this.chatService,
    this.profileStore = const StartupProfileStore(),
  });
  final AccountService service;
  final ChatService? chatService;
  final StartupProfileStore profileStore;
  final Widget Function(bool newUser)? experienceBuilder;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Read the device locale, not MaterialApp's selected interface language.
  // Keep the selected login flow stable until this gate is recreated.
  late final bool _usePhoneLogin =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode
          ?.toUpperCase() ==
      'CN';
  bool _loading = true, _authenticated = false, _newUser = false;
  String? _error;
  Map<String, dynamic> _profile = {};
  bool _returning = false;
  String? _uid;
  Map<String, dynamic> _userProfile = {};
  bool _introCompletedThisVisit = false;

  Future<void> _authenticatedSession(AccountSession session) async {
    final profile = await widget.profileStore.readUser(session.uid);
    final pending =
        profile['registrationChat'] == 'pending' ||
        ((widget.service.testNewUser || session.isNewUser) &&
            profile['registrationChat'] != 'done');
    final next = {
      ...profile,
      if (pending) 'registrationChat': 'pending',
      if (pending && _introCompletedThisVisit) 'introDone': true,
    };
    if (pending) await widget.profileStore.writeUser(session.uid, next);
    if (!mounted) return;
    setState(() {
      _userProfile = next;
      _uid = session.uid;
      _newUser = pending;
      _authenticated = true;
    });
  }

  Future<void> _completeRegistrationChat() async {
    final value = {..._userProfile, 'registrationChat': 'done'};
    await widget.profileStore.writeUser(_uid!, value);
    if (!mounted) return;
    setState(() {
      _userProfile = value;
      _newUser = false;
    });
  }

  Future<bool> _advance(String? next) async {
    if (_authenticated) {
      final value = {..._userProfile, 'page': next, 'introDone': next == null};
      await widget.profileStore.writeUser(_uid!, value);
      if (mounted) setState(() => _userProfile = value);
    } else {
      final value = {..._profile, 'page': next, 'introDone': next == null};
      await widget.profileStore.write(value);
      if (mounted) {
        setState(() {
          _profile = value;
          _introCompletedThisVisit = next == null;
        });
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.service.restoreSession();
      _profile = await widget.profileStore.read();
      if (session == null) {
        _returning = await widget.service.hasCompletedRegistration();
      } else {
        // Credentials can survive an interrupted/failed first profile write.
        // Apply the same new-user decision as a fresh login before routing.
        await _authenticatedSession(session);
      }
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _authenticated = false;
          _uid = null;
          _newUser = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取登录状态，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF100621),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextButton(onPressed: _restore, child: const AppText('重试')),
                  ],
                ),
        ),
      );
    }
    if (!_authenticated && !_returning && _profile['introDone'] != true) {
      return OnboardingFlow(
        initialPageId: _profile['page'] as String?,
        onAdvance: _advance,
        onComplete: () {},
      );
    }
    if (_authenticated && _newUser && _userProfile['introDone'] != true) {
      return OnboardingFlow(
        key: ValueKey('onboarding-$_uid'),
        initialPageId: _userProfile['page'] as String?,
        onAdvance: _advance,
        onComplete: () {},
      );
    }
    if (_authenticated &&
        _newUser &&
        (_userProfile['name'] as String? ?? '').isEmpty) {
      return NamePage(
        onContinue: (name) async {
          final value = {..._userProfile, 'name': name};
          await widget.profileStore.writeUser(_uid!, value);
          if (mounted) setState(() => _userProfile = value);
        },
      );
    }
    if (!_authenticated) {
      if (!_usePhoneLogin) {
        return GoogleLoginPage(
          service: widget.service,
          onAuthenticated: _authenticatedSession,
        );
      }
      return PhoneLoginPage(
        service: widget.service,
        onAuthenticated: _authenticatedSession,
      );
    }
    return widget.experienceBuilder?.call(_newUser) ??
        ExperiencePage(
          key: ValueKey(_uid),
          userId: _uid!,
          accountService: widget.service,
          chatService: widget.chatService,
          profileStore: widget.profileStore,
          registrationCompleted: true,
          returningUser: !_newUser,
          onRegistrationChatComplete: _completeRegistrationChat,
        );
  }
}
