import 'package:flutter/material.dart';

/// Reusable blue gradient background container.
class BlueGradientBackground extends StatelessWidget {
  /// Creates a gradient background wrapper.
  const BlueGradientBackground({super.key, required this.child});

  /// Foreground content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F9FF), Color(0xFFE6F1FF), Color(0xFFD8E8FF)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
