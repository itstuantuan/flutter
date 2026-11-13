import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'onboarding_texture.dart';
import 'onboarding_page.dart';

/// Native text and width-driven artwork; only empty space flexes with height.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.pageIndex = 0,
    required this.onNext,
    required this.header,
    required this.visualBuilder,
    this.textureAsset,
    this.textureRect = Rect.zero,
    required this.spaceWeights,
    this.background = const [],
    this.footerOverlap = 0,
    this.nextLabel = '继续了解',
    this.busy = false,
    this.error,
  });

  final String nextLabel;
  final int pageIndex;
  final VoidCallback onNext;
  final Widget header;
  final Widget Function(double width) visualBuilder;
  final List<Widget> background;
  final String? textureAsset;
  final Rect textureRect;
  final ({int top, int middle, int bottom}) spaceWeights;
  final double footerOverlap;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final page = OnboardingPageScope.maybeOf(context);
    final pageIndex = page?.index ?? this.pageIndex;
    final pageCount = page?.count ?? 2;
    final nextLabel = page?.nextLabel ?? this.nextLabel;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF431E89),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF431E89),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final safe = MediaQuery.paddingOf(context);
            final availableWidth = math.max(
              1.0,
              constraints.maxWidth - safe.horizontal,
            );
            final contentWidth = math.min(availableWidth, 600.0);
            final bottomGap = ((constraints.maxHeight - 600) * 28 / 212).clamp(
              12.0,
              28.0,
            );
            final bottom = math.max(34.0, safe.bottom) + bottomGap + 2;
            final buttonHeight = math.max(
              56.0,
              MediaQuery.textScalerOf(context).scale(16) * 1.25 + 24,
            );
            const indicatorHeight = 13.043;
            const indicatorGap = 16.48;
            final footerHeight = buttonHeight + indicatorGap + indicatorHeight;
            final textureScale = constraints.maxWidth / 375;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (background.isNotEmpty)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 375,
                        height: 812,
                        child: Stack(children: background),
                      ),
                    ),
                  ),
                if (textureAsset != null)
                  Positioned(
                    left: textureRect.left * textureScale,
                    top: textureRect.top * textureScale,
                    width: textureRect.width * textureScale,
                    height: textureRect.height * textureScale,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: OnboardingLuminosityTexture(
                        asset: textureAsset!,
                        size: textureRect.size,
                      ),
                    ),
                  ),
                Positioned(
                  top: safe.top,
                  left: safe.left,
                  right: safe.right,
                  bottom: bottom + footerHeight - footerOverlap,
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      key: ValueKey('onboarding-content-$pageIndex'),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: viewport.maxHeight,
                            maxWidth: contentWidth,
                          ),
                          child: _FlexibleContent(
                            weights: spaceWeights,
                            children: [header, visualBuilder(contentWidth)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: safe.left,
                  right: safe.right,
                  bottom: bottom,
                  child: Center(
                    child: SizedBox(
                      width: math.min(availableWidth * 291 / 375, 466),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: '引导，第 ${pageIndex + 1} 页，共 $pageCount 页',
                            child: pageCount == 2
                                ? Image.asset(
                                    'assets/onboarding/${pageIndex == 0 ? 'indicator' : 'world_indicator'}.png',
                                    width: 30,
                                    height: indicatorHeight,
                                    fit: BoxFit.fill,
                                    excludeFromSemantics: true,
                                  )
                                : SizedBox(
                                    height: indicatorHeight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0; i < pageCount; i++)
                                          Container(
                                            width: 11,
                                            height: 11,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: i == pageIndex
                                                  ? const Color(0xFF8CC6FF)
                                                  : Colors.white24,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: indicatorGap),
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: FilledButton(
                              onPressed: busy ? null : onNext,
                              style: FilledButton.styleFrom(
                                overlayColor: Colors.transparent,
                                backgroundColor: const Color(0xFFF44BE6),
                                disabledBackgroundColor: const Color(
                                  0xFFF44BE6,
                                ),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (busy)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/onboarding/next_icon.png',
                                      width: 22,
                                      height: 22,
                                      excludeFromSemantics: true,
                                    ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      nextLabel,
                                      style: const TextStyle(
                                        fontFamily: 'PingFang SC',
                                        letterSpacing: 1,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: math.max(4, safe.bottom),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Wraps naturally for narrow screens and accessibility text sizes.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.left,
    required this.right,
    required this.titleGap,
    required this.descriptionGap,
    required this.descriptionSize,
    required this.descriptionLineHeight,
  });
  final String title, subtitle, description;
  final double left,
      right,
      titleGap,
      descriptionGap,
      descriptionSize,
      descriptionLineHeight;

  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(
      fontFamily: 'PingFang SC',
      fontSize: 36,
      height: 1.25,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: Colors.white,
    );
    return Padding(
      padding: EdgeInsets.only(left: left, right: right),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: heading),
          SizedBox(height: titleGap),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF7DD5FF), Color(0xFFFF85D6)],
            ).createShader(Rect.fromLTWH(0, 0, 216, bounds.height)),
            child: Text(subtitle, style: heading),
          ),
          SizedBox(height: descriptionGap),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: descriptionSize,
              height: descriptionLineHeight / descriptionSize,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: const Color(0xF5FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Measures actual wrapped content once, then allocates only surplus space.
/// A scroll view supplies unbounded height; when content is taller than the
/// viewport the minimum gaps remain and the scroll view handles the remainder.
class _FlexibleContent extends MultiChildRenderObjectWidget {
  const _FlexibleContent({required this.weights, required super.children});
  final ({int top, int middle, int bottom}) weights;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFlexibleContent(weights);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFlexibleContent renderObject,
  ) {
    renderObject.weights = weights;
  }
}

class _RenderFlexibleContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OnboardingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OnboardingParentData> {
  _RenderFlexibleContent(this._weights);
  ({int top, int middle, int bottom}) _weights;
  set weights(({int top, int middle, int bottom}) value) {
    if (_weights == value) return;
    _weights = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OnboardingParentData) {
      child.parentData = _OnboardingParentData();
    }
  }

  @override
  void performLayout() {
    assert(childCount == 2);
    final header = firstChild!;
    final visual = lastChild!;
    final childConstraints = BoxConstraints.tightFor(
      width: constraints.maxWidth,
    );
    header.layout(childConstraints, parentUsesSize: true);
    visual.layout(childConstraints, parentUsesSize: true);
    final naturalHeight = 16 + header.size.height + 12 + visual.size.height;
    size = constraints.constrain(Size(constraints.maxWidth, naturalHeight));
    final spare = math.max(0.0, size.height - naturalHeight);
    final totalWeight = _weights.top + _weights.middle + _weights.bottom;
    final headerTop = 16 + spare * _weights.top / totalWeight;
    (header.parentData! as _OnboardingParentData).offset = Offset(0, headerTop);
    (visual.parentData! as _OnboardingParentData).offset = Offset(
      0,
      headerTop +
          header.size.height +
          12 +
          spare * _weights.middle / totalWeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _OnboardingParentData extends ContainerBoxParentData<RenderBox> {}
