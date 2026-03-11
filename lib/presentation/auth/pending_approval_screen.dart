import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proctor/presentation/common/blue_gradient_background.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';

/// Screen shown when an account is still pending or inactive.
class PendingApprovalScreen extends StatelessWidget {
  /// Creates the pending screen.
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menunggu Akses'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthController>().signOut(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: BlueGradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SectionCard(
                title: 'Akun Belum Aktif',
                subtitle:
                    'Flow ini mengikuti rule bahwa user pending tidak boleh mengakses sesi ujian.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nama: ${user?.displayName ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Email: ${user?.email ?? '-'}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tunggu persetujuan super admin atau aktivasi ulang akun sebelum login kembali.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
