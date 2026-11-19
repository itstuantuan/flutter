import 'dart:async';

import 'package:flutter/material.dart';

final _activeToasts = Expando<OverlayEntry>();

void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  final route = ModalRoute.of(context);
  if (overlay == null || route?.isCurrent == false) return;

  final previous = _activeToasts[overlay];
  previous?.remove();
  previous?.dispose();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppToast(
      message: message,
      route: route,
      onDismiss: () {
        if (_activeToasts[overlay] != entry) return;
        _activeToasts[overlay] = null;
        entry.remove();
        entry.dispose();
      },
    ),
  );
  _activeToasts[overlay] = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({required this.message, this.route, required this.onDismiss});

  final String message;
  final ModalRoute<dynamic>? route;
  final VoidCallback onDismiss;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 24,
    right: 24,
    bottom:
        MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom +
        72,
    child: IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.route?.animation,
          widget.route?.secondaryAnimation,
        ]),
        builder: (context, child) =>
            widget.route?.isCurrent == false ? const SizedBox.shrink() : child!,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              color: const Color(0xF02B2337),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
