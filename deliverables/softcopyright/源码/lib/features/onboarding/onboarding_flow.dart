import 'package:flutter/material.dart';

import 'onboarding_page.dart';
import 'onboarding_pages.dart';

/// Shared by startup and design preview. Completion never marks registration.
class OnboardingFlow extends StatefulWidget {
  OnboardingFlow({
    super.key,
    List<OnboardingPageDefinition>? pages,
    this.initialPageId,
    this.onAdvance,
    required this.onComplete,
    this.busy = false,
    this.error,
  }) : pages = List.unmodifiable(pages ?? onboardingPages) {
    if (this.pages.isEmpty ||
        this.pages.any((page) => page.id.isEmpty) ||
        this.pages.map((page) => page.id).toSet().length != this.pages.length) {
      throw ArgumentError('引导页面列表不能为空，且每页必须有唯一的非空 ID');
    }
  }

  final List<OnboardingPageDefinition> pages;
  final String? initialPageId;

  /// Persist the next ID, or null on completion. False keeps the current page.
  final Future<bool> Function(String? nextPageId)? onAdvance;
  final VoidCallback onComplete;
  final bool busy;
  final String? error;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late String _pageId;
  bool _advancing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageId = widget.pages.any((p) => p.id == widget.initialPageId)
        ? widget.initialPageId!
        : widget.pages.first.id;
  }

  @override
  void didUpdateWidget(covariant OnboardingFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.pages.any((p) => p.id == _pageId)) {
      _pageId = widget.pages.first.id;
    }
  }

  Future<void> _next() async {
    if (_advancing || widget.busy) return;
    final index = widget.pages.indexWhere((p) => p.id == _pageId);
    final next = index + 1 < widget.pages.length
        ? widget.pages[index + 1].id
        : null;
    setState(() {
      _advancing = true;
      _error = null;
    });
    try {
      final saved = await widget.onAdvance?.call(next) ?? true;
      if (!mounted || !saved) return;
      if (next == null) {
        widget.onComplete();
      } else {
        setState(() => _pageId = next);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.pages.indexWhere((p) => p.id == _pageId);
    final page = widget.pages[index];
    return OnboardingPageScope(
      key: ValueKey(page.id),
      index: index,
      count: widget.pages.length,
      nextLabel: page.nextLabel,
      child: page.builder(
        _next,
        widget.busy || _advancing,
        widget.error ?? _error,
      ),
    );
  }
}
