import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proctor/data/models/app_user.dart';
import 'package:proctor/data/models/exam_session.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';

/// Main dashboard for the super admin role.
class AdminDashboardScreen extends StatelessWidget {
  /// Creates the admin dashboard.
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final sessionController = context.watch<SessionController>();
    final sessions = sessionController.visibleSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Super Admin'),
        actions: [
          IconButton(
            onPressed: () => _showCreateSessionDialog(context),
            icon: const Icon(Icons.add_task),
            tooltip: 'Buat sesi',
          ),
          TextButton(
            onPressed: () => authController.signOut(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _OverviewCard(
            totalSessions: sessions.length,
            activeSessions: sessions
                .where((s) => s.status == SessionStatus.active)
                .length,
            pendingUsers: authController.pendingUsers.length,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Approval Proctor',
            subtitle:
                'User baru harus diubah dari pending menjadi proctor aktif.',
            child: authController.pendingUsers.isEmpty
                ? const Text('Tidak ada user pending.')
                : Column(
                    children: authController.pendingUsers
                        .map((user) => _PendingUserRow(user: user))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Proctor Aktif',
            subtitle:
                'Super admin tetap memegang kontrol aktivasi akun pengawas.',
            child: Column(
              children: authController.approvedProctors
                  .map((user) => _ProctorRow(user: user))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Sesi Ujian',
            subtitle:
                'Super admin bisa membuat, mengaktifkan, dan mengakhiri sesi.',
            trailing: FilledButton.icon(
              onPressed: () => _showCreateSessionDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Buat Sesi'),
            ),
            child: Column(
              children: sessions
                  .map((session) => _SessionRow(session: session))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSessionDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final durationController = TextEditingController(text: '120');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Buat Sesi Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama sesi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL ujian'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durasi ujian (menit)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final durationMinutes = int.tryParse(durationController.text);

                if (durationMinutes == null || durationMinutes <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Durasi ujian harus berupa angka positif.'),
                    ),
                  );
                  return;
                }

                final session = await context
                    .read<SessionController>()
                    .createSession(
                      name: nameController.text,
                      examUrl: urlController.text,
                      durationMinutes: durationMinutes,
                    );

                if (!context.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                if (session != null) {
                  context.go('/sessions/${session.id}');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    urlController.dispose();
    durationController.dispose();
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalSessions,
    required this.activeSessions,
    required this.pendingUsers,
  });

  final int totalSessions;
  final int activeSessions;
  final int pendingUsers;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Ringkasan',
      subtitle:
          'Scaffold ini sudah mengikuti pemisahan role dan status sesi aktif.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricChip(label: 'Total sesi', value: '$totalSessions'),
          _MetricChip(label: 'Sesi aktif', value: '$activeSessions'),
          _MetricChip(label: 'Pending approval', value: '$pendingUsers'),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _PendingUserRow extends StatelessWidget {
  const _PendingUserRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(user.displayName),
      subtitle: Text(user.email),
      trailing: FilledButton(
        onPressed: () => context.read<AuthController>().approveProctor(user.id),
        child: const Text('Approve'),
      ),
    );
  }
}

class _ProctorRow extends StatelessWidget {
  const _ProctorRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(user.displayName),
      subtitle: Text(user.email),
      trailing: Switch(
        value: user.isActive,
        onChanged: (isActive) {
          context.read<AuthController>().setProctorActive(
            userId: user.id,
            isActive: isActive,
          );
        },
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(session.name),
      subtitle: Text('${session.status.label} • ${session.examUrl}'),
      trailing: FilledButton.tonal(
        onPressed: () => context.go('/sessions/${session.id}'),
        child: const Text('Detail'),
      ),
    );
  }
}
