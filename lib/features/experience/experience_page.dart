import '../settings/language_page.dart';
import '../../core/localization/app_localizations.dart';
import '../discoveries/discovery_detail_page.dart';

import 'dart:async';

import '../notifications/push_service.dart';
import '../notifications/notification_discovery_page.dart';
import '../shared/app_toast.dart';
import '../home/home_page.dart';
import '../discoveries/all_discoveries_page.dart';
import '../home/home_sidebar.dart';
import '../settings/settings_store.dart';
import '../settings/profile_page.dart';
import '../settings/feedback_page.dart';
import '../settings/notification_pages.dart';
import '../settings/privacy_policy_page.dart';
import '../settings/service_agreement_page.dart';
import '../plaza/plaza_page.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/interests_page.dart';
import '../auth/startup_profile_store.dart';
import '../chat/chat_page.dart';
import '../chat/live_chat_page.dart';
import '../chat/chat_service.dart';
import '../exploration/exploration_controller.dart';
import '../exploration/exploration_store.dart';
import '../exploration/live_plaza_page.dart';
import '../exploration/plaza_entry_page.dart';

import 'package:flutter/material.dart';

import '../auth/account_service.dart';
import '../auth/auth_gate.dart';
import '../../core/config/app_env.dart';
import 'experience_controller.dart';
import 'experience_store.dart';

class ExperiencePage extends StatefulWidget {
  const ExperiencePage({
    super.key,
    this.controller,
    this.accountService,
    this.chatService,
    this.previewWelcomeOnStart = false,
    this.registrationCompleted = false,
    this.returningUser = true,
    this.onRegistrationChatComplete,
    this.userId = 'local-preview',
    this.profileStore = const StartupProfileStore(),
  });
  final bool previewWelcomeOnStart;
  final bool registrationCompleted;
  final bool returningUser;
  final String userId;
  final StartupProfileStore profileStore;
  final Future<void> Function()? onRegistrationChatComplete;
  final ExperienceController? controller;
  final AccountService? accountService;
  final ChatService? chatService;
  @override
  State<ExperiencePage> createState() => _ExperiencePageState();
}

class _ExperiencePageState extends State<ExperiencePage>
    with WidgetsBindingObserver {
  late final ExperienceController flow;
  final input = TextEditingController();
  final push = PushService();
  ExplorationController? _bots;
  Future<void>? _botInitialization;
  bool _foreground = true;
  AccountService get _account => widget.accountService ?? account;
  bool get _real => widget.registrationCompleted;

  Future<void> _initializeBots() async {
    try {
      final profile = await widget.profileStore.readUser(widget.userId);
      if (!mounted) return;
      final bots = ExplorationController(
        service: widget.chatService ?? ChatService.authenticated(_account),
        store: SecureExplorationStore(
          namespace: '${AppEnv.apiBaseUrl}.${widget.userId}',
        ),
        displayName: profile['name'] as String? ?? _account.session?.nick ?? '',
        onUnauthorized: () async {
          await _account.logout();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => AuthGate(service: _account),
            ),
            (_) => false,
          );
        },
      );
      _bots = bots;
      bots.addListener(refresh);
      if (!_foreground) bots.pause();
      await bots.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _notice('无法初始化探索，请退出后重试');
    }
  }

  Future<ExplorationController> _readyBots() async {
    await _botInitialization;
    final bots = _bots;
    if (bots == null || !bots.ready) throw const ChatException('探索尚未就绪，请稍后重试');
    return bots;
  }

  Future<void> _discoveryVisible(String taskId) async {
    try {
      await _bots?.acknowledgeTask(taskId);
    } catch (e) {
      await _bots?.reportError(e);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalProfile());
    WidgetsBinding.instance.addObserver(this);
    if (_real) {
      push.attachAccount(_account);
      _botInitialization = _initializeBots();
    } else {
      flow = widget.controller ?? ExperienceController(LocalExperienceStore());
      flow.addListener(refresh);
      flow.load();
    }
    push.addListener(refresh);
    push.initialize();
  }

  bool _notificationRouting = false;
  bool _showHomeFromNotification = false;
  Route<void>? _notificationChatRoute;

  void _openRemoteNotification() {
    final raw = push.pendingNotification;
    if (raw == null) return;
    if (!_real ||
        !_foreground ||
        _notificationRouting ||
        _account.session == null) {
      return;
    }
    final notification = ExplorationNotification.parse(raw);
    final session = _account.session!;
    _notificationRouting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || !_foreground || !identical(_account.session, session)) {
          return;
        }
        final homeRoute = ModalRoute.of(context);
        if (homeRoute?.isActive != true) return;
        push.pendingNotification = null;
        final navigator = Navigator.of(context);
        if (notification == null) {
          _showHomeFromNotification = true;
          navigator.popUntil((route) => identical(route, homeRoute));
          return;
        }
        final previousChat = _notificationChatRoute;
        if (previousChat?.isActive == true) {
          navigator.removeRoute(previousChat!);
        }
        final chatRoute = MaterialPageRoute<void>(
          builder: (_) => NotificationDiscoveryPage(
            notification: notification,
            account: _account,
            session: session,
            service: widget.chatService ?? ChatService.forSession(session),
            onDisplayed: (task) async {
              await _botInitialization;
              if (mounted && identical(_account.session, session)) {
                await _discoveryVisible(task);
              }
            },
          ),
        );
        _notificationChatRoute = chatRoute;
        unawaited(
          navigator.push(chatRoute).whenComplete(() {
            if (identical(_notificationChatRoute, chatRoute)) {
              _notificationChatRoute = null;
            }
          }),
        );
      } finally {
        _notificationRouting = false;
        if (mounted && ModalRoute.of(context)?.isActive == true) refresh();
      }
    });
  }

  bool _welcomePreviewDismissed = false;
  bool _finishingRegistration = false;
  String? _registrationError;

  Future<void> _finishRegistrationChat({bool explore = false}) async {
    if (_finishingRegistration) return;
    setState(() {
      _finishingRegistration = true;
      _registrationError = null;
    });
    try {
      final bots = await _readyBots();
      final selection = await bots.interests();
      if (!mounted) return;
      final ids = List<String>.from(selection['selected'] as List? ?? []);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (routeContext) => InterestsPage(
            initialSelection: interestIds.entries
                .where((entry) => ids.contains(entry.value))
                .map((entry) => entry.key)
                .toList(),
            onStart: (labels) async {
              try {
                await bots.saveInterests(labels);
                await widget.onRegistrationChatComplete?.call();
                final task = await bots.startExploration();
                if (task == null || !routeContext.mounted) return false;
                // Keep interests covering home until the exploration route
                // replaces it. There is no pop-to-home between these screens.
                unawaited(
                  Navigator.of(routeContext).pushReplacement<void, void>(
                    MaterialPageRoute(
                      builder: (_) => LivePlazaPage(
                        controller: bots,
                        taskId: task,
                        onChat: (voice) => _homeChat(record: voice),
                        onOpenDiscovery: _showDiscoveryDetail,
                      ),
                    ),
                  ),
                );
                return true;
              } catch (e) {
                await bots.reportError(e);
                return false;
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _registrationError = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _finishingRegistration = false);
    }
  }

  void refresh() {
    if (!mounted) return;
    setState(() {});
    _openRemoteNotification();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      push.refresh();
      _bots?.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _bots?.pause();
    }
    refresh();
  }

  @override
  void dispose() {
    _bots?.removeListener(refresh);
    _bots?.dispose();
    push.removeListener(refresh);
    push.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (!_real) {
      flow.removeListener(refresh);
      if (widget.controller == null) flow.dispose();
    }
    input.dispose();
    super.dispose();
  }

  Future<void> detail(int index) async {
    await flow.markRead(index);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                flow.discoveryTitle(index),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(flow.discoveryBody(index)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  input.text = '聊聊「${flow.discoveryTitle(index)}」';
                  Navigator.pop(context);
                },
                child: const AppText('带回聊天继续聊'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _showOnboarding {
    if (_real || !flow.ready) return false;
    if (widget.previewWelcomeOnStart) return !_welcomePreviewDismissed;
    return flow.step == ExperienceStep.welcome ||
        flow.step == ExperienceStep.world;
  }

  Future<bool> _advanceOnboarding(String? nextPageId) async {
    if (flow.busy) return false;
    if (flow.step == ExperienceStep.welcome ||
        flow.step == ExperienceStep.world) {
      await flow.advanceOnboarding(nextPageId);
      return flow.error == null;
    }
    // Design review must not overwrite an existing user's mock experience.
    return true;
  }

  bool get _showHome =>
      _real ||
      (flow.ready &&
          (flow.step == ExperienceStep.home ||
              (widget.previewWelcomeOnStart && _welcomePreviewDismissed)));

  void _notice(String message) => showAppToast(context, message);

  final _settingsStore = const SettingsStore();
  LocalUserProfile _localProfile = const LocalUserProfile();
  String get _displayName =>
      _localProfile.name ?? _account.session?.nick ?? (_real ? '' : flow.name);

  Future<void> _loadLocalProfile() async {
    try {
      final profile = await _settingsStore.profile(widget.userId);
      if (mounted) setState(() => _localProfile = profile);
    } catch (_) {}
  }

  Future<void> _homeMenu() async {
    final selection = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: translate(context, '关闭侧栏'),
      barrierColor: Colors.black.withValues(alpha: .3),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (drawerContext, animation, secondaryAnimation) =>
          HomeSidebar(
            name: _displayName,
            avatar: _localProfile.avatar,
            avatarUrl: _account.session?.avatar,
            onSelect: (value) => Navigator.pop(drawerContext, value),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    if (!mounted || selection == null) return;
    switch (selection) {
      case 'history':
        await _allDiscoveries(onlyHistory: true);
      case 'language':
        await _selectLanguage();
      case 'interests':
        await _sidebarInterests();
      case 'profile':
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              name: _displayName,
              uid: _account.session?.uid ?? widget.userId,
              avatar: _localProfile.avatar,
              avatarUrl: _account.session?.avatar,
              onSave: (profile) async {
                await _settingsStore.saveProfile(widget.userId, profile);
                if (mounted) setState(() => _localProfile = profile);
              },
              onLogout: () async {
                await _account.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => AuthGate(service: _account),
                  ),
                  (_) => false,
                );
              },
            ),
          ),
        );
      case 'notifications':
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      case 'feedback':
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                FeedbackPage(uid: widget.userId, store: _settingsStore),
          ),
        );
      case 'about':
        await _sidebarInfo('关于我们', 'Pals\n让陪伴与灵感融入每一天。\n\n版本 1.0.0');
    }
  }

  Future<void> _selectLanguage() =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const LanguagePage()));

  Future<void> _sidebarInterests() async {
    try {
      final bots = _real ? await _readyBots() : null;
      final selection = await bots?.interests();
      final ids = List<String>.from(selection?['selected'] as List? ?? []);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (routeContext) => InterestsPage(
            initialSelection: bots == null
                ? flow.interests
                : interestIds.entries
                      .where((entry) => ids.contains(entry.value))
                      .map((entry) => entry.key)
                      .toList(),
            onStart: (labels) async {
              try {
                if (bots != null) {
                  await bots.saveInterests(labels);
                } else {
                  await flow.saveInterests(labels);
                }
                if (routeContext.mounted) Navigator.pop(routeContext);
                return true;
              } catch (_) {
                if (mounted) _notice('兴趣保存失败，请重试');
                return false;
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) _notice('无法加载兴趣，请稍后重试');
    }
  }

  Future<void> _sidebarInfo(
    String title,
    String message,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (pageContext) => Scaffold(
        backgroundColor: const Color(0xFF33303B),
        appBar: AppBar(
          title: AppText(title),
          backgroundColor: const Color(0xFF33303B),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText(
                '服务协议',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () => Navigator.of(pageContext).push<void>(
                MaterialPageRoute(builder: (_) => const ServiceAgreementPage()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText(
                '隐私政策',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () => Navigator.of(pageContext).push<void>(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _homeChat({
    bool record = false,
    String? taskId,
    String? materialId,
    Map<String, dynamic>? referenceCard,
  }) async {
    if (_real) {
      try {
        await _readyBots();
      } catch (_) {
        if (mounted) _notice('聊天尚未就绪，请稍后重试');
        return;
      }
      if (!mounted) return;
    }
    final explore = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (chatContext) => widget.registrationCompleted
            ? LiveChatPage(
                accountService: _account,
                controller: _bots?.chat,
                taskId: taskId,
                discoveryCards: _bots?.cards ?? const [],
                materialId: materialId,
                referenceCard: referenceCard,
                onDiscoveryVisible: _discoveryVisible,
                initialDraft: input.text,
                startRecordingOnOpen: record,
                onExit: () => Navigator.pop(chatContext, false),
                onExplore: () => Navigator.pop(chatContext, true),
              )
            : ListenableBuilder(
                listenable: flow,
                builder: (_, _) => ChatPage(
                  name: flow.character.name,
                  referenceCard: referenceCard,
                  returningUser: true,
                  messages: flow.chatMessages,
                  busy: flow.busy,
                  error: flow.error,
                  initialDraft: input.text,
                  startRecordingOnOpen: record,
                  onSend: (text) async {
                    await flow.send(text);
                    if (flow.error == null) input.clear();
                    return flow.error == null;
                  },
                  onVoiceRecorded: flow.saveVoice,
                  onExit: () => Navigator.pop(chatContext, false),
                  onExplore: () => Navigator.pop(chatContext, true),
                ),
              ),
      ),
    );
    if (explore == true && mounted) await _explore();
  }

  bool _exploreOpening = false;
  Future<void> _explore() async {
    if (_exploreOpening) return;
    _exploreOpening = true;
    try {
      if (_real) {
        await _exploreLive();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PlazaEntryPage(
            displayName: flow.name,
            prepare: (entryContext) async {
              var selected = await widget.profileStore.hasSelectedInterests(
                widget.userId,
              );
              if (!entryContext.mounted) return null;
              if (!selected) {
                selected =
                    await Navigator.of(entryContext).push<bool>(
                      MaterialPageRoute(
                        builder: (routeContext) => InterestsPage(
                          onStart: (values) async {
                            await flow.saveInterests(values);
                            if (flow.error != null) return false;
                            await widget.profileStore.saveSelectedInterests(
                              widget.userId,
                              values,
                            );
                            if (routeContext.mounted) {
                              Navigator.pop(routeContext, true);
                            }
                            return true;
                          },
                        ),
                      ),
                    ) ==
                    true;
              }
              if (!selected || !entryContext.mounted) return null;
              return PlazaPage(
                displayName: flow.name,
                onChat: _homeChat,
                onVoice: () => _homeChat(record: true),
              );
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) _notice('无法读取兴趣选择，请重试');
    } finally {
      _exploreOpening = false;
    }
  }

  Future<void> _exploreLive() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlazaEntryPage(
          displayName: _displayName,
          prepare: (entryContext) async {
            final bots = await _readyBots();
            if (!entryContext.mounted) return null;
            final task = await bots.startExploration(
              isCurrent: () => entryContext.mounted,
              confirmInterests: (selection) async {
                if (!entryContext.mounted) return false;
                final ids = List<String>.from(
                  selection['selected'] as List? ?? [],
                );
                final confirmed = await Navigator.of(entryContext).push<bool>(
                  MaterialPageRoute(
                    builder: (routeContext) => InterestsPage(
                      initialSelection: interestIds.entries
                          .where((entry) => ids.contains(entry.value))
                          .map((entry) => entry.key)
                          .toList(),
                      onStart: (labels) async {
                        try {
                          await bots.saveInterests(labels);
                          if (routeContext.mounted) {
                            Navigator.pop(routeContext, true);
                          }
                          return true;
                        } catch (e) {
                          await bots.reportError(e);
                          return false;
                        }
                      },
                    ),
                  ),
                );
                return confirmed == true;
              },
            );
            if (!entryContext.mounted) return null;
            if (task == null) {
              if (bots.error != null) throw ChatException(bots.error!);
              return null;
            }
            return LivePlazaPage(
              controller: bots,
              taskId: task,
              onChat: (voice) => _homeChat(record: voice),
              onOpenDiscovery: _showDiscoveryDetail,
            );
          },
        ),
      ),
    );
    if (mounted) {
      unawaited(
        _bots?.refreshHome().catchError((Object e) => _bots?.reportError(e)),
      );
    }
  }

  Future<void> _showDiscoveryDetail(Map<String, dynamic> card) async {
    final quote = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DiscoveryDetailPage(
          card: card,
          history: _bots?.cards ?? [card],
          service: _bots?.service,
        ),
      ),
    );
    if (!mounted || quote == null) return;
    await _homeChat(
      taskId: (quote['_chatTaskId'] ?? quote['taskId']) as String?,
      materialId: quote['materialId'] as String?,
      referenceCard: quote,
    );
  }

  Future<void> _allDiscoveries({bool onlyHistory = false}) async {
    if (_real) {
      try {
        await _readyBots();
      } catch (_) {
        if (mounted) _notice('发现暂时无法加载，请稍后重试');
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AllDiscoveriesPage(
          onlyHistory: onlyHistory,
          service: _real ? _bots?.service : null,
          cards: _real
              ? _bots?.cards ?? []
              : [
                  for (var i = 0; i < flow.discoveryCount; i++)
                    {
                      'title': flow.discoveryTitle(i),
                      'summary': flow.discoveryBody(i),
                      '_index': i,
                    },
                ],
          onOpen: (card) async {
            if (_real) {
              final task = card['taskId'];
              if (task is String && task.isNotEmpty) {
                await _showDiscoveryDetail(card);
              } else {
                _notice('这条发现缺少定位信息');
              }
            } else {
              await _homeDiscovery(card['_index'] as int);
            }
          },
        ),
      ),
    );
  }

  Future<void> _homeDiscovery(int index) async {
    if (_real) {
      final cards = _bots?.cards ?? [];
      if (index < 0 || index >= cards.length) return;
      final card = cards[index];
      final task = card['taskId'];
      if (task is! String || task.isEmpty) {
        _notice('这条发现缺少定位信息');
        return;
      }
      await _showDiscoveryDetail(card);
      return;
    }
    if (flow.discoveryCount > index) {
      await _showDiscoveryDetail({
        'title': flow.discoveryTitle(index),
        'summary': flow.discoveryBody(index),
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlazaPage(
          displayName: flow.name,
          initialDiscovery: index,
          onChat: _homeChat,
          onVoice: () => _homeChat(record: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _real && !widget.returningUser && !_showHomeFromNotification
      ? _bots == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : LiveChatPage(
                accountService: _account,
                controller: _bots?.chat,
                onDiscoveryVisible: _discoveryVisible,
                returningUser: false,
                error: _registrationError,
                busy: _finishingRegistration,
                onExit: _finishRegistrationChat,
                onExplore: () => _finishRegistrationChat(explore: true),
              )
      : _showOnboarding
      ? OnboardingFlow(
          initialPageId: widget.previewWelcomeOnStart
              ? null
              : flow.onboardingPageId,
          busy: flow.busy,
          error: flow.error,
          onAdvance: _advanceOnboarding,
          onComplete: () => setState(() => _welcomePreviewDismissed = true),
        )
      : _showHome
      ? HomePage(
          hintUserId: widget.userId,
          onMenu: _homeMenu,
          onFriends: () => _notice('好友功能尚未开放'),
          onExplore: _explore,
          onChat: _homeChat,
          onVoice: () => _homeChat(record: true),
          onDiscovery: _homeDiscovery,
          onAllDiscoveries: _allDiscoveries,
          loadingDiscoveries: _real && (_bots?.loadingCards ?? true),
          discoveries: _real
              ? [
                  for (final (i, card)
                      in (_bots?.cards ?? <Map<String, dynamic>>[]).indexed)
                    HomeDiscovery(
                      card: card,
                      title: card['title'] as String? ?? '',
                      description: card['text'] as String? ?? '',
                      style: DiscoveryStyle
                          .values[i % DiscoveryStyle.values.length],
                    ),
                ]
              : flow.discoveryCount == 0
              ? HomePage.designDiscoveries
              : [
                  for (var i = 0; i < flow.discoveryCount; i++)
                    HomeDiscovery(
                      description: flow.isRead(i) ? '已读发现' : '探索带回了新发现：',
                      title: flow.discoveryTitle(i),
                      style: i == 0
                          ? DiscoveryStyle.blue
                          : DiscoveryStyle.purple,
                    ),
                ],
        )
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}
