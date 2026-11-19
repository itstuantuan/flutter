import 'package:flutter/material.dart';

/// Applies the designer's source-image crop inside the 375×812 scene viewport.
/// The caller scales the scene uniformly and can extend the sky above the crop.
class DesignScene extends StatelessWidget {
  const DesignScene({
    super.key,
    required this.asset,
    required this.sourceRect,
    required this.semanticLabel,
    this.topExtension = 0,
  });
  final String asset, semanticLabel;
  final Rect sourceRect;
  final double topExtension;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final scale = c.maxWidth / 375;
      final skyHeight = -sourceRect.top * scale;
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: sourceRect.left * scale,
              top: topExtension + sourceRect.top * scale,
              width: sourceRect.width * scale,
              height: sourceRect.height * scale,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                semanticLabel: semanticLabel,
              ),
            ),
            // Reveal the sky above the design crop as the scene moves down.
            // If the offset exceeds that crop, stretch only the sky strip.
            if (skyHeight > 0 && topExtension > skyHeight)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topExtension,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        left: sourceRect.left * scale,
                        top: 0,
                        width: sourceRect.width * scale,
                        height:
                            sourceRect.height *
                            scale *
                            (topExtension / skyHeight),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
