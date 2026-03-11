import 'package:flutter/material.dart';

/// Lightweight splash used while auth state initializes.
class SplashScreen extends StatelessWidget {
  /// Creates the splash screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Menyiapkan Proctor App...'),
          ],
        ),
      ),
    );
  }
}
