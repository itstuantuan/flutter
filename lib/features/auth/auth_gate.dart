import 'package:flutter/material.dart';

import '../experience/experience_page.dart';
import 'account_service.dart';
import 'phone_login_page.dart';
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
    this.profileStore = const StartupProfileStore(),
  });
  final AccountService service;
  final StartupProfileStore profileStore;
  final Widget Function(bool newUser)? experienceBuilder;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true, _authenticated = false, _newUser = false;
  String? _error;
  Map<String, dynamic> _profile = {};
  bool _returning = false;
  String? _uid;
  Map<String, dynamic> get _registrationChats =>
      Map<String, dynamic>.from(_profile['registrationChats'] as Map? ?? {});

  Future<void> _authenticatedSession(AccountSession session) async {
    final chats = _registrationChats;
    final pending =
        widget.service.testNewUser ||
        chats[session.uid] == 'pending' ||
        (session.isNewUser && chats[session.uid] != 'done');
    if (pending) {
      final value = {
        ..._profile,
        'registrationChats': {...chats, session.uid: 'pending'},
      };
      await widget.profileStore.write(value);
      _profile = value;
    }
    if (!mounted) return;
    setState(() {
      _uid = session.uid;
      _newUser = pending;
      _authenticated = true;
    });
  }

  Future<void> _completeRegistrationChat() async {
    final value = {
      ..._profile,
      'registrationChats': {..._registrationChats, _uid!: 'done'},
    };
    await widget.profileStore.write(value);
    if (!mounted) return;
    setState(() {
      _profile = value;
      _newUser = false;
    });
  }

  Future<bool> _advance(String? next) async {
    final value = {..._profile, 'page': next, 'introDone': next == null};
    await widget.profileStore.write(value);
    if (mounted) setState(() => _profile = value);
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
      }
      if (!mounted) return;
      setState(() {
        _authenticated = session != null;
        _uid = session?.uid;
        _newUser =
            session != null && _registrationChats[session.uid] == 'pending';
      });
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
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    TextButton(onPressed: _restore, child: const Text('重试')),
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
    if (_authenticated &&
        _newUser &&
        (_profile['name'] as String? ?? '').isEmpty) {
      return NamePage(
        onContinue: (name) async {
          final value = {..._profile, 'name': name};
          await widget.profileStore.write(value);
          if (mounted) setState(() => _profile = value);
        },
      );
    }
    if (!_authenticated) {
      return PhoneLoginPage(
        service: widget.service,
        onAuthenticated: _authenticatedSession,
      );
    }
    return widget.experienceBuilder?.call(_newUser) ??
        ExperiencePage(
          userId: _uid!,
          profileStore: widget.profileStore,
          registrationCompleted: true,
          returningUser: !_newUser,
          onRegistrationChatComplete: _completeRegistrationChat,
        );
  }
}
