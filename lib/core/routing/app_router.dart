import 'package:go_router/go_router.dart';
import 'package:proctor/data/models/user_role.dart';
import 'package:proctor/presentation/auth/login_screen.dart';
import 'package:proctor/presentation/auth/pending_approval_screen.dart';
import 'package:proctor/presentation/auth/register_screen.dart';
import 'package:proctor/presentation/dashboard/admin_dashboard_screen.dart';
import 'package:proctor/presentation/dashboard/proctor_dashboard_screen.dart';
import 'package:proctor/presentation/sessions/session_detail_screen.dart';
import 'package:proctor/presentation/splash/splash_screen.dart';
import 'package:proctor/state/auth_controller.dart';

/// Central route configuration for the Proctor app.
class AppRouter {
  /// Creates the app router.
  AppRouter(AuthController authController)
    : router = GoRouter(
        initialLocation: '/splash',
        refreshListenable: authController,
        routes: [
          GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
          GoRoute(
            path: '/pending',
            builder: (_, _) => const PendingApprovalScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (_, _) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/proctor',
            builder: (_, _) => const ProctorDashboardScreen(),
          ),
          GoRoute(
            path: '/sessions/:sessionId',
            builder: (_, state) => SessionDetailScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
        redirect: (context, state) {
          if (!authController.isReady) {
            return state.matchedLocation == '/splash' ? null : '/splash';
          }

          final user = authController.currentUser;
          final location = state.matchedLocation;
          final isAuthRoute = location == '/login' || location == '/register';

          if (user == null) {
            if (isAuthRoute) {
              return null;
            }

            return '/login';
          }

          if (user.role == UserRole.pending) {
            return location == '/pending' ? null : '/pending';
          }

          if (location == '/splash' ||
              location == '/login' ||
              location == '/register' ||
              location == '/pending') {
            return user.role.homeLocation;
          }

          if (location == '/admin' && user.role != UserRole.superAdmin) {
            return user.role.homeLocation;
          }

          if (location == '/proctor' && user.role != UserRole.proctor) {
            return user.role.homeLocation;
          }

          return null;
        },
      );

  /// GoRouter instance used by MaterialApp.
  final GoRouter router;
}
