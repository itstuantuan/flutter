import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma 541:2081. The preview retains the identity of the quoted discovery.
class DiscoveryReference extends StatelessWidget {
  const DiscoveryReference({
    super.key,
    required this.card,
    required this.onDismiss,
  });
  final Map<String, dynamic> card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final url = card['coverUrl'] as String?;
    Widget fallback() =>
        Image.asset('assets/chat/reference_thumbnail.png', fit: BoxFit.cover);
    return Container(
      key: const ValueKey('discovery-reference'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCF141020),
        border: Border.all(color: const Color(0x2EFFFFFF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 70,
              height: 51,
              child: url?.startsWith('https://') == true
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback(),
                    )
                  : fallback(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF683CB7),
                        borderRadius: BorderRadius.circular(57),
                      ),
                      child: const AppText(
                        '引用发现',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        tooltip: translate(context, '取消引用'),
                        padding: EdgeInsets.zero,
                        onPressed: onDismiss,
                        icon: SvgPicture.asset(
                          'assets/chat/reference_close.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  card['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
