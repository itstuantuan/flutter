import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../chat/chat_service.dart';
import 'all_discoveries_page.dart';

/// Figma 541:826. Returning a card requests a conversation about that discovery.
class DiscoveryDetailPage extends StatefulWidget {
  const DiscoveryDetailPage({
    super.key,
    required this.card,
    this.history = const [],
    this.service,
  });
  final Map<String, dynamic> card;
  final List<Map<String, dynamic>> history;
  final ChatService? service;
  @override
  State<DiscoveryDetailPage> createState() => _DiscoveryDetailPageState();
}

class _DiscoveryDetailPageState extends State<DiscoveryDetailPage> {
  // Presentation-only until a discovery feedback endpoint is available.
  bool? _liked;
  String text(String key) => (widget.card[key] as String? ?? '').trim();
  Widget icon(String name, double size) =>
      SvgPicture.asset('assets/chat/$name.svg', width: size, height: size);

  Widget _feedback(bool like) {
    final selected = _liked == like;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(91),
            border: Border.all(color: const Color(0x5CD4C9EB)),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF5832EF), Color(0xFF8B42DE)],
                  )
                : null,
          ),
          child: TextButton(
            onPressed: () => setState(() => _liked = selected ? null : like),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 39),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.flip(
                  flipY: !like,
                  child: icon(
                    'detail_${like ? 'like' : 'dislike'}${selected ? '_selected' : ''}',
                    24,
                  ),
                ),
                const SizedBox(width: 6),
                AppText(like ? '喜欢' : '不喜欢'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = (widget.card['tags'] as List? ?? []).whereType<String>();
    final labels = <String>{
      if (discoveryCategory(widget.card).isNotEmpty)
        discoveryCategory(widget.card),
      for (final tag in tags) discoveryCategory({'category': tag}),
    };
    final body =
        [
          'content',
          'summary',
          'text',
          'reason',
        ].map(text).where((s) => s.isNotEmpty).firstOrNull ??
        '';
    final cover = text('coverUrl');
    final scale = MediaQuery.sizeOf(context).width / 375;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A093A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              key: const ValueKey('discovery-detail-scroll'),
              padding: EdgeInsets.only(
                bottom: 108 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 295 * scale,
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cover.startsWith('https://'))
                            Image.network(
                              cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _scene(),
                            )
                          else
                            _scene(),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xA819171C),
                                  Colors.transparent,
                                  Color(0xFF1A093A),
                                ],
                                stops: [0, .45, 1],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final label in labels)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  gradient: LinearGradient(
                                    colors: label == labels.first
                                        ? const [
                                            Color(0x30B9A5FF),
                                            Color(0x304FFFFF),
                                          ]
                                        : const [
                                            Color(0x30FFDAC5),
                                            Color(0x30B6FFB8),
                                          ],
                                  ),
                                ),
                                child: AppText(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text('title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          body,
                          style: const TextStyle(
                            color: Color(0xDAFFFFFF),
                            fontSize: 15,
                            height: 22 / 15,
                          ),
                        ),
                        const SizedBox(height: 34),
                        SvgPicture.asset(
                          'assets/chat/detail_divider.svg',
                          width: 329,
                          height: 6,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        const AppText(
                          '这类发现，你喜欢吗？',
                          style: TextStyle(
                            color: Color(0xB6FFFFFF),
                            fontSize: 14,
                            height: 22 / 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _feedback(false),
                            const SizedBox(width: 11),
                            _feedback(true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 57,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const AppText(
                        '新发现',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: translate(context, '返回'),
                            onPressed: () => Navigator.pop(context),
                            icon: icon('detail_back', 24),
                          ),
                          const Spacer(),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(104),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2EA5EF), Color(0xFFA43ADD)],
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, widget.card),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon('detail_chat', 24),
                      const SizedBox(width: 7),
                      const AppText(
                        '和Pal聊聊',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scene() => LayoutBuilder(
    builder: (_, constraints) {
      final scale = constraints.maxWidth / 375;
      return Stack(
        children: [
          Positioned(
            left: -180.155 * scale,
            top: -7.974 * scale,
            width: 794.495 * scale,
            height: 335.177 * scale,
            child: Image.asset('assets/chat/detail_pets.png', fit: BoxFit.fill),
          ),
        ],
      );
    },
  );
}
