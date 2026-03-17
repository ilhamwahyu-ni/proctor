import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proctor/presentation/common/blue_gradient_background.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';

/// Main dashboard for the proctor role.
class ProctorDashboardScreen extends StatelessWidget {
  /// Creates the proctor dashboard.
  const ProctorDashboardScreen({super.key});

  String _maskExamUrl(String url) {
    if (url.length <= 20) {
      return '....';
    }

    return '${url.substring(0, url.length - 20)}....';
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final sessions = context.watch<SessionController>().visibleSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Aktif'),
        actions: [
          if (authController.isImpersonating)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => authController.stopImpersonating(),
              icon: const Icon(Icons.cancel),
              label: const Text('Stop Impersonating'),
            )
          else
            IconButton(
              onPressed: () => authController.signOut(),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
        ],
      ),
      body: BlueGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionCard(
              title:
                  'Halo, ${authController.currentUser?.displayName ?? 'Proctor'}',
              subtitle:
                  'Halaman ini hanya menampilkan sesi dengan status active sesuai rule role proctor.',
              child: const Text(
                'Buka detail sesi untuk melihat Exit OTP yang berlaku 60 menit dan Alarm OTP yang berlaku 30 detik.',
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Daftar Sesi Aktif',
              child: sessions.isEmpty
                  ? const Text('Belum ada sesi aktif yang bisa diakses.')
                  : Column(
                      children: sessions
                          .map(
                            (session) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(session.name),
                              subtitle: Text(_maskExamUrl(session.examUrl)),
                              trailing: FilledButton(
                                onPressed: () =>
                                    context.push('/sessions/${session.id}'),
                                child: const Text('Lihat OTP'),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
