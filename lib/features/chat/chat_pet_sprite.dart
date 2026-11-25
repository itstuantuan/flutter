import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Artwork for the chat companion. Expressions are painted over the image at
/// fractional eye boxes, so swapping the art only needs those boxes measured.
@immutable
class ChatPetSkin {
  const ChatPetSkin({
    required this.image,
    required this.aspectRatio,
    required this.leftEye,
    required this.rightEye,
    required this.body,
    required this.skinColor,
    required this.lashColor,
  });

  final String image;

  /// Width / height of [image].
  final double aspectRatio;

  /// Eye boxes as fractions of the image.
  final Rect leftEye, rightEye;

  /// Opaque part of the image as fractions; used for collision checks so the
  /// transparent margin may overlap neighbours.
  final Rect body;
  final Color skinColor, lashColor;

  static const viitor = ChatPetSkin(
    image: 'assets/characters/viitor_idle.png',
    aspectRatio: 1086 / 1448,
    leftEye: Rect.fromLTRB(.352, .322, .477, .394),
    rightEye: Rect.fromLTRB(.585, .337, .712, .406),
    body: Rect.fromLTRB(.12, .04, .89, .98),
    skinColor: Color(0xFFFBE4E0),
    lashColor: Color(0xFF3B2441),
  );
}

enum ChatPetExpression { open, blink, happy, sleepy }

enum ChatPetEmote {
  note(Icons.music_note_rounded),
  exclaim(Icons.priority_high_rounded),
  question(Icons.question_mark_rounded),
  heart(Icons.favorite_rounded, Color(0xFFFF5FAE)),
  sparkle(Icons.auto_awesome_rounded, Color(0xFFF2B33D)),
  thinking(Icons.more_horiz_rounded),
  sleep(Icons.bedtime_rounded, Color(0xFF7C6BD6));

  const ChatPetEmote(this.icon, [this.color = const Color(0xFF8E5BF0)]);
  final IconData icon;
  final Color color;
}

/// Body deformation for one frame. All transforms pivot on the feet.
@immutable
class ChatPetFrame {
  const ChatPetFrame({
    this.scaleX = 1,
    this.scaleY = 1,
    this.tilt = 0,
    this.lift = 0,
    this.mirror = false,
    this.opacity = 1,
  });
  final double scaleX, scaleY, tilt, lift, opacity;
  final bool mirror;
}

class ChatPetSprite extends StatelessWidget {
  const ChatPetSprite({
    super.key,
    required this.size,
    this.skin = ChatPetSkin.viitor,
    this.frame = const ChatPetFrame(),
    this.expression = ChatPetExpression.open,
    this.emote,
    this.emoteProgress = 1,
    this.emoteOnLeft = false,
    this.shadow = true,
  });

  final Size size;
  final ChatPetSkin skin;
  final ChatPetFrame frame;
  final ChatPetExpression expression;
  final ChatPetEmote? emote;
  final double emoteProgress;
  final bool emoteOnLeft, shadow;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          skin.image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
        if (expression != ChatPetExpression.open)
          CustomPaint(painter: _FacePainter(skin, expression)),
      ],
    );
    final shadowScale = (1 - frame.lift / 60).clamp(.35, 1.0);
    return SizedBox.fromSize(
      size: size,
      child: Opacity(
        opacity: frame.opacity.clamp(0.0, 1.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (shadow)
              Positioned(
                left: size.width * .2,
                right: size.width * .2,
                bottom: -2,
                height: 5,
                child: Transform.scale(
                  scaleX: shadowScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(20, 8, 40, .32 * shadowScale),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(30, 3),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, -frame.lift),
                child: Transform.rotate(
                  angle: frame.tilt,
                  alignment: Alignment.bottomCenter,
                  child: Transform.scale(
                    scaleX: frame.scaleX * (frame.mirror ? -1 : 1),
                    scaleY: frame.scaleY,
                    alignment: Alignment.bottomCenter,
                    child: body,
                  ),
                ),
              ),
            ),
            if (emote case final emote?)
              Positioned(
                top: -size.height * .06 - frame.lift,
                left: emoteOnLeft ? -size.width * .02 : null,
                right: emoteOnLeft ? null : -size.width * .02,
                child: _EmoteBubble(emote: emote, progress: emoteProgress),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmoteBubble extends StatelessWidget {
  const _EmoteBubble({required this.emote, required this.progress});
  final ChatPetEmote emote;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pop = Curves.elasticOut.transform(progress.clamp(0.0, 1.0));
    return Transform.scale(
      scale: pop,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x66A17DC5), width: .8),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
        ),
        child: Icon(emote.icon, size: 13, color: emote.color),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.skin, this.expression);
  final ChatPetSkin skin;
  final ChatPetExpression expression;

  @override
  void paint(Canvas canvas, Size size) {
    for (final eye in [skin.leftEye, skin.rightEye]) {
      final r = Rect.fromLTRB(
        eye.left * size.width,
        eye.top * size.height,
        eye.right * size.width,
        eye.bottom * size.height,
      );
      final cover = r.inflate(r.width * .05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cover, Radius.circular(cover.height * .45)),
        Paint()..color = skin.skinColor,
      );
      final lash = Paint()
        ..color = skin.lashColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(.9, r.width * .14);
      final y = r.top + r.height * .6;
      final path = Path()..moveTo(r.left + r.width * .05, y);
      switch (expression) {
        case ChatPetExpression.happy:
          // ^ ^
          path.quadraticBezierTo(
            r.center.dx,
            y - r.height * .7,
            r.right - r.width * .05,
            y,
          );
        case ChatPetExpression.sleepy:
          path.quadraticBezierTo(
            r.center.dx,
            y + r.height * .12,
            r.right - r.width * .05,
            y,
          );
        case ChatPetExpression.blink || ChatPetExpression.open:
          path.quadraticBezierTo(
            r.center.dx,
            y + r.height * .32,
            r.right - r.width * .05,
            y,
          );
      }
      canvas.drawPath(path, lash);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.expression != expression || old.skin != skin;
}
