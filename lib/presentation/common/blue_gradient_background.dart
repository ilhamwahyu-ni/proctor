import 'package:flutter/material.dart';

/// Reusable gradient background container derived from theme colors.
class BlueGradientBackground extends StatelessWidget {
  /// Creates a gradient background wrapper.
  const BlueGradientBackground({super.key, required this.child});

  /// Foreground content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surface, cs.surfaceContainerLow],
        ),
      ),
      child: child,
    );
  }
}
