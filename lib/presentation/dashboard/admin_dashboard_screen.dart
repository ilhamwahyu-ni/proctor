import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
        actions: [

          IconButton(
            onPressed: () => _showCreateSessionDialog(context),
            icon: const Icon(Icons.add_task),
            tooltip: 'Buat sesi',
          ),
          IconButton(
            onPressed: () => authController.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: BlueGradientBackground(
        child: Column(
          children: [
            Expanded(
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

                  SectionCard(
                    title: 'Proctor Aktif',
                    subtitle:
                        'Daftar pengawas aktif menggunakan pagination agar list tetap ringkas.',

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
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://ilwa.my.id');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    'Develop by ilwa.my.id',
                    style: TextStyle(
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
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

    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Buat Sesi Baru'),
              content: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedDate == null
                            ? 'Pilih Tanggal'
                            : 'Tanggal: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedTime == null
                            ? 'Pilih Jam'
                            : 'Jam: ${selectedTime!.format(context)}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => selectedTime = time);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        urlController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama dan URL wajib diisi.')),
                      );
                      return;
                    }

                    final durationMinutes = int.tryParse(durationController.text);
                    if (durationMinutes == null || durationMinutes <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Durasi ujian harus berupa angka positif.'),
                        ),
                      );
                      return;
                    }

                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pilih tanggal dan waktu ujian.'),
                        ),
                      );
                      return;
                    }

                    final startsAt = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    // Capture navigator, messenger and router before async gap
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogContext);
                    final router = GoRouter.of(context);

                    final session = await context
                        .read<SessionController>()
                        .createSession(
                          name: nameController.text,
                          examUrl: urlController.text,
                          durationMinutes: durationMinutes,
                          startsAt: startsAt,
                        );

                    navigator.pop();

                    if (session != null) {
                      router.push('/sessions/${session.id}');
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Sesi berhasil dibuat.')),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
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
      subtitle: 'Ringkasan sesi dan status approval proctor.',
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
        onPressed: () => context.push('/sessions/${session.id}'),
        child: const Text('Detail'),
      ),
    );
  }
}
