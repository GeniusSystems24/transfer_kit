import 'package:flutter/material.dart';

/// A simple Hero animation wrapper widget.
///
/// Wraps a child widget with Hero animation capabilities.
class HeroCard extends StatelessWidget {
  /// The unique tag for the hero animation
  final String tag;

  /// The child widget to wrap
  final Widget child;

  /// Optional callback when the hero is tapped
  final VoidCallback? onTap;

  /// Creates a HeroCard widget
  const HeroCard({
    super.key,
    required this.tag,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget heroChild = Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    if (onTap != null) {
      heroChild = GestureDetector(
        onTap: onTap,
        child: heroChild,
      );
    }

    return heroChild;
  }
}
