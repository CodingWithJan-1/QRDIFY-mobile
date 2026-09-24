import 'package:flutter/material.dart';

/// Keeps visited tabs mounted while adding a short directional transition.
class AnimatedTabStack extends StatelessWidget {
  const AnimatedTabStack({
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 240),
    this.slideDistance = 0.035,
    super.key,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;
  final Duration duration;
  final double slideDistance;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    final paintOrder = <int>[
      for (var childIndex = 0; childIndex < children.length; childIndex++)
        if (childIndex != index) childIndex,
      index,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final childIndex in paintOrder)
          _AnimatedTab(
            key: ValueKey(childIndex),
            isActive: childIndex == index,
            offset: childIndex == index
                ? Offset.zero
                : Offset(
                    childIndex < index ? -slideDistance : slideDistance,
                    0,
                  ),
            duration: effectiveDuration,
            child: children[childIndex],
          ),
      ],
    );
  }
}

class _AnimatedTab extends StatelessWidget {
  const _AnimatedTab({
    required this.isActive,
    required this.offset,
    required this.duration,
    required this.child,
    super.key,
  });

  final bool isActive;
  final Offset offset;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !isActive,
      child: IgnorePointer(
        ignoring: !isActive,
        child: TickerMode(
          enabled: isActive,
          child: AnimatedSlide(
            offset: offset,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isActive ? 1 : 0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
