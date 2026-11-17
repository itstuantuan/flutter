import 'package:flutter/material.dart';

import '../plaza/plaza_page.dart';

/// Navigation happens before preparation; network failures stay on this route.
class PlazaEntryPage extends StatefulWidget {
  const PlazaEntryPage({
    super.key,
    required this.prepare,
    this.displayName = '',
  });
  final Future<Widget?> Function(BuildContext context) prepare;
  final String displayName;
  @override
  State<PlazaEntryPage> createState() => _PlazaEntryPageState();
}

class _PlazaEntryPageState extends State<PlazaEntryPage> {
  Widget? _ready;
  bool _loading = true;
  bool _preparing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    if (!mounted || _preparing) return;
    _preparing = true;
    setState(() => _loading = true);
    try {
      final page = await widget.prepare(context);
      if (!mounted) return;
      if (page == null) {
        Navigator.pop(context);
        return;
      }
      setState(() => _ready = page);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _preparing = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _ready ??
      Stack(
        children: [
          PlazaPage(
            displayName: widget.displayName,
            onChat: () {},
            onVoice: () {},
            onDiscovery: () {},
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 24,
            right: 24,
            child: Material(
              color: Colors.black.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (_loading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _loading ? '正在准备探索…' : '探索加载失败，请重试',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!_loading)
                      TextButton(
                        onPressed: _prepare,
                        child: const Text(
                          '重试',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}
