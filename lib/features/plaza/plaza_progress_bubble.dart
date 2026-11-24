import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays server phases and elapsed time, never an estimated percentage.
class PlazaProgressBubble extends StatelessWidget {
  const PlazaProgressBubble({
    super.key,
    required this.phase,
    this.elapsedSeconds,
    this.unavailable = false,
    this.onOpenDiscovery,
  });
  final String phase;
  final int? elapsedSeconds;
  final bool unavailable;
  final VoidCallback? onOpenDiscovery;

  @override
  Widget build(BuildContext context) {
    final complete = phase == 'complete';
    final title = unavailable
        ? '正在同步探索状态'
        : switch (phase) {
            'searching' => 'Pal 努力探索中',
            'complete' => 'Pal 带着发现回来啦',
            'empty' => '这次还没找到新发现',
            'failed' => '这次探索没能完成',
            _ => '正在获取探索进度',
          };
    final elapsed = elapsedSeconds;
    final detail = unavailable
        ? '连接恢复后会自动更新'
        : switch (phase) {
            'complete' => '点我看看这次的收获',
            'empty' => '回首页，换个方向再出发吧',
            'failed' => '回首页后可以重新出发',
            'searching' when elapsed != null && elapsed >= 0 =>
              elapsed < 60
                  ? '已探索 $elapsed 秒 · 发现后告诉你'
                  : '已探索 ${elapsed ~/ 60} 分 ${elapsed % 60} 秒',
            'searching' => '正在寻找你会喜欢的新鲜事',
            _ => '稍等一下，马上告诉你',
          };
    return Semantics(
      liveRegion: true,
      button: complete && !unavailable,
      child: GestureDetector(
        onTap: complete && !unavailable ? onOpenDiscovery : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF2523B82), Color(0xF02B2146)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xA8CBB2FF), width: .8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33201738),
                    blurRadius: 18,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child: SvgPicture.asset(
                          'assets/chat/greeting_star.svg',
                          excludeFromSemantics: true,
                        ),
                      ),
                      Expanded(
                        child: AppText(
                          title,
                          style: const TextStyle(
                            fontFamily: 'PingFang SC',
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    detail,
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      color: Color(0xE6E5D9FA),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  if (phase == 'searching' && !unavailable) ...[
                    const SizedBox(height: 9),
                    const Row(
                      children: [
                        _Dot(Color(0xFFB4ECFF)),
                        SizedBox(width: 4),
                        _Dot(Color(0xFFAFA0F7)),
                        SizedBox(width: 4),
                        _Dot(Color(0xFF766294)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: CustomPaint(
                size: const Size(14, 9),
                painter: _BubbleTail(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _BubbleTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(3, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xF02B2146));
    final edge = Path()
      ..moveTo(0, 0)
      ..lineTo(3, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      edge,
      Paint()
        ..color = const Color(0xA8CBB2FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) => false;
}
