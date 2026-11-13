import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Figma uses luminosity blending here; a normal PNG draw shifts dots to pink.
class OnboardingLuminosityTexture extends StatefulWidget {
  const OnboardingLuminosityTexture({
    super.key,
    this.asset = 'dots',
    this.size = const Size(346.34, 272.31),
  });
  final String asset;
  final Size size;
  @override
  State<OnboardingLuminosityTexture> createState() =>
      OnboardingLuminosityTextureState();
}

class OnboardingLuminosityTextureState
    extends State<OnboardingLuminosityTexture> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final _listener = ImageStreamListener((image, synchronousCall) {
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
    });
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant OnboardingLuminosityTexture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _resolveImage();
  }

  void _resolveImage() {
    final stream = AssetImage('assets/onboarding/${widget.asset}.png')
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: widget.size, painter: _TexturePainter(_image?.image));
}

class _TexturePainter extends CustomPainter {
  const _TexturePainter(this.image);
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) {
    final texture = image;
    if (texture == null) return;
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      Offset.zero & size,
      Paint()..blendMode = BlendMode.luminosity,
    );
  }

  @override
  bool shouldRepaint(covariant _TexturePainter oldDelegate) =>
      image != oldDelegate.image;
}
