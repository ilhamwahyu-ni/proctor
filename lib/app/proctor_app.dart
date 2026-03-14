import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proctor/core/routing/app_router.dart';
import 'package:proctor/core/theme/app_theme.dart';

/// Root application widget for the Proctor app.
class ProctorApp extends StatelessWidget {
  /// Creates the root application widget.
  const ProctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = context.read<AppRouter>();

    return MaterialApp.router(
      title: 'Proctor App',
      theme: AppTheme.light(),
      routerConfig: appRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
