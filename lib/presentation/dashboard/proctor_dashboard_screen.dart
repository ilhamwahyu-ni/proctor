import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';

/// Main dashboard for the proctor role.
class ProctorDashboardScreen extends StatelessWidget {
  /// Creates the proctor dashboard.
  const ProctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final sessions = context.watch<SessionController>().visibleSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Aktif'),
        actions: [
          TextButton(
            onPressed: () => authController.signOut(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionCard(
            title:
                'Halo, ${authController.currentUser?.displayName ?? 'Proctor'}',
            subtitle:
                'Halaman ini hanya menampilkan sesi dengan status active sesuai rule role proctor.',
            child: const Text(
              'Buka detail sesi untuk melihat Exit OTP dan Alarm OTP yang digenerate lokal tiap 30 detik.',
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
                            subtitle: Text(session.examUrl),
                            trailing: FilledButton(
                              onPressed: () =>
                                  context.go('/sessions/${session.id}'),
                              child: const Text('Lihat OTP'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
