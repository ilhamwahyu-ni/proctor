import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proctor/data/models/app_user.dart';
import 'package:proctor/data/models/exam_session.dart';
import 'package:proctor/presentation/common/blue_gradient_background.dart';
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
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x803A86FF), Color(0x80278AFF), Color(0x8052A3FF)],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateProctorDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Tambah proctor',
          ),
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
      body: BlueGradientBackground(
        child: ListView(
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
            const _CreateProctorSection(),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Proctor Aktif',
              subtitle:
                  'Daftar pengawas aktif menggunakan pagination agar list tetap ringkas.',
              trailing: FilledButton.icon(
                onPressed: () => _showCreateProctorDialog(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tambah Proctor'),
              ),
              child: _ActiveProctorPagination(
                proctors: authController.activeProctors,
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

  Future<void> _showCreateProctorDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah User Proctor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama proctor'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password awal'),
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
                final success = await context
                    .read<AuthController>()
                    .createManagedProctor(
                      email: emailController.text,
                      displayName: nameController.text,
                      password: passwordController.text,
                    );

                if (!context.mounted) {
                  return;
                }

                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email proctor sudah terdaftar.'),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User proctor berhasil ditambahkan.'),
                  ),
                );
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
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

class _CreateProctorSection extends StatefulWidget {
  const _CreateProctorSection();

  @override
  State<_CreateProctorSection> createState() => _CreateProctorSectionState();
}

class _CreateProctorSectionState extends State<_CreateProctorSection> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Tambah Proctor',
      subtitle:
          'Super admin bisa membuat akun pengawas aktif secara langsung dari dashboard.',
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama proctor'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password awal'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_isSubmitting ? 'Menambahkan...' : 'Tambah Proctor'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final displayName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, email, dan password wajib diisi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await context.read<AuthController>().createManagedProctor(
      email: email,
      displayName: displayName,
      password: password,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email proctor sudah terdaftar.')),
      );
      return;
    }

    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User proctor berhasil ditambahkan.')),
    );
  }
}

class _ActiveProctorPagination extends StatefulWidget {
  const _ActiveProctorPagination({required this.proctors});

  final List<AppUser> proctors;

  @override
  State<_ActiveProctorPagination> createState() =>
      _ActiveProctorPaginationState();
}

class _ActiveProctorPaginationState extends State<_ActiveProctorPagination> {
  static const int _pageSize = 4;
  int _page = 0;

  @override
  void didUpdateWidget(covariant _ActiveProctorPagination oldWidget) {
    super.didUpdateWidget(oldWidget);

    final maxPage = _pageCount == 0 ? 0 : _pageCount - 1;
    if (_page > maxPage) {
      _page = maxPage;
    }
  }

  int get _pageCount {
    return (widget.proctors.length / _pageSize).ceil();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.proctors.isEmpty) {
      return const Text('Belum ada proctor aktif.');
    }

    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.proctors.length);
    final items = widget.proctors.sublist(start, end);

    return Column(
      children: [
        ...items.map((user) => _ProctorRow(user: user)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Halaman ${_page + 1} dari $_pageCount'),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _page == 0
                      ? null
                      : () => setState(() => _page -= 1),
                  child: const Text('Sebelumnya'),
                ),
                FilledButton.tonal(
                  onPressed: _page >= _pageCount - 1
                      ? null
                      : () => setState(() => _page += 1),
                  child: const Text('Berikutnya'),
                ),
              ],
            ),
          ],
        ),
      ],
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
