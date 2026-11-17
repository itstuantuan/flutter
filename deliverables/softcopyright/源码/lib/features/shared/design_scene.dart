import 'package:flutter/material.dart';

/// Applies the designer's source-image crop inside the 375×812 scene viewport.
/// The caller scales the viewport uniformly; the image is never height-squeezed.
class DesignScene extends StatelessWidget {
  const DesignScene({
    super.key,
    required this.asset,
    required this.sourceRect,
    required this.semanticLabel,
  });
  final String asset, semanticLabel;
  final Rect sourceRect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final scale = c.maxWidth / 375;
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: sourceRect.left * scale,
              top: sourceRect.top * scale,
              width: sourceRect.width * scale,
              height: sourceRect.height * scale,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                semanticLabel: semanticLabel,
              ),
            ),
          ],
        ),
      );
    },
  );
}
