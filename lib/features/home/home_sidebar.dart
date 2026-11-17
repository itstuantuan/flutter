import 'dart:math' as math;
import 'dart:typed_data';

import '../settings/profile_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home drawer from Figma 414:3770. System bars remain platform controlled.
class HomeSidebar extends StatelessWidget {
  const HomeSidebar({
    super.key,
    required this.name,
    required this.onSelect,
    this.unreadCount = 0,
    this.avatar,
    this.avatarUrl,
    this.version = '0.1.0',
  });
  final String name, version;
  final Uint8List? avatar;
  final String? avatarUrl;
  final int unreadCount;
  final ValueChanged<String> onSelect;

  Widget _arrow() =>
      SvgPicture.asset('assets/sidebar/chevron.svg', width: 16, height: 16);
  Widget _row(
    String id,
    String label,
    String asset, {
    bool badge = false,
  }) => InkWell(
    onTap: () => onSelect(id),
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SvgPicture.asset('assets/sidebar/$asset.svg', width: 22, height: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 23 / 15,
              ),
            ),
          ),
          if (badge && unreadCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5454),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
          ],
          _arrow(),
        ],
      ),
    ),
  );
  Widget _group(List<Widget> children, {double opacity = .06}) => Material(
    color: Colors.white.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final safe = MediaQuery.paddingOf(context);
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: math.min(constraints.maxWidth * 316 / 375, 400),
          height: constraints.maxHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(60),
            ),
            child: Material(
              color: const Color(0xFF39334C),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/sidebar/background.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    left: -60,
                    bottom: 77,
                    width: 334,
                    height: 209,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: .04,
                        child: Image.asset(
                          'assets/sidebar/watermark.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: SafeArea(
                      right: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(15, 10, 15, 100),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => onSelect('profile'),
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 60,
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: ProfileAvatar(
                                        bytes: avatar,
                                        url: avatarUrl,
                                        size: 44,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        name.isEmpty ? '我的资料' : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _arrow(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _group([
                              _row(
                                'notifications',
                                '系统通知',
                                'notifications',
                                badge: true,
                              ),
                              _row('interests', '兴趣选择', 'interests'),
                            ], opacity: .08),
                            const SizedBox(height: 20),
                            _group([_row('feedback', '反馈问题', 'feedback')]),
                            const SizedBox(height: 14),
                            _group([_row('about', '关于我们', 'about')]),
                            const SizedBox(height: 14),
                            _group([
                              InkWell(
                                onTap: () => onSelect('debug'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tune,
                                        color: Colors.white70,
                                        size: 22,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '调试工具',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.white38,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: math.max(32, safe.bottom),
                    child: IgnorePointer(
                      child: Text(
                        'Pals      v$version',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
