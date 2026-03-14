import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proctor/app/proctor_app.dart';
import 'package:proctor/core/routing/app_router.dart';
import 'package:proctor/data/repositories/auth_repository.dart';
import 'package:proctor/data/repositories/session_repository.dart';
import 'package:proctor/firebase_options.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProctorBootstrap());
}

/// Boots the Proctor application with repositories and shared state.
class ProctorBootstrap extends StatelessWidget {
  /// Creates the root bootstrap widget.
  const ProctorBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<SessionRepository>(create: (_) => SessionRepository()),
        ChangeNotifierProvider<AuthController>(
          create: (context) {
            final controller = AuthController(context.read<AuthRepository>());
            controller.initialize();
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, SessionController>(
          create: (context) => SessionController(
            sessionRepository: context.read<SessionRepository>(),
            authController: context.read<AuthController>(),
          ),
          update: (context, authController, previous) {
            if (previous != null) {
              previous.attachAuth(authController);
              return previous;
            }

            return SessionController(
              sessionRepository: context.read<SessionRepository>(),
              authController: authController,
            );
          },
        ),
        ProxyProvider<AuthController, AppRouter>(
          update: (_, authController, previous) =>
              previous ?? AppRouter(authController),
        ),
      ],
      child: const ProctorApp(),
    );
  }
}
