import 'package:flutter/material.dart';

import '../../core/config/app_env.dart';

class DiscoveryImage extends StatelessWidget {
  const DiscoveryImage({
    super.key,
    required this.card,
    required this.fallback,
    this.fit = BoxFit.cover,
  });
  final Map<String, dynamic> card;
  final Widget fallback;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final illustration = card['illustration'] as Map?;
    Widget load(String? raw, bool isFallback) {
      if (raw == null || raw.isEmpty) return fallback;
      final uri = Uri.parse(AppEnv.apiBaseUrl).resolve(raw);
      if (!['http', 'https'].contains(uri.scheme)) return fallback;
      return Image.network(
        uri.toString(),
        fit: fit,
        errorBuilder: (_, _, _) => isFallback
            ? fallback
            : load(illustration?['fallbackUrl'] as String?, true),
      );
    }

    return load((illustration?['url'] ?? card['coverUrl']) as String?, false);
  }
}
