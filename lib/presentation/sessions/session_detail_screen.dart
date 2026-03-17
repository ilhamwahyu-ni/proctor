import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:otp/otp.dart';
import 'package:provider/provider.dart';
import 'package:proctor/data/models/exam_session.dart';
import 'package:proctor/data/models/user_role.dart';
import 'package:proctor/presentation/common/blue_gradient_background.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saver_gallery/saver_gallery.dart';

/// Session detail screen showing QR payload and live OTP codes.
class SessionDetailScreen extends StatefulWidget {
  /// Creates the session detail screen.
  const SessionDetailScreen({super.key, required this.sessionId});

  /// Session identifier from the route.
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  static const int _exitOtpIntervalSeconds = 3600;
  static const int _alarmOtpIntervalSeconds = 60;

  late final Timer _timer;
  DateTime _now = DateTime.now();
  bool _isDownloading = false;

  String _maskExamUrl(String url) {
    if (url.length <= 20) {
      return '....';
    }

    return '${url.substring(0, url.length - 20)}....';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>().sessionById(
      widget.sessionId,
    );
    final user = context.watch<AuthController>().currentUser;
    final isSuperAdmin = user?.role == UserRole.superAdmin;

    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sesi tidak ditemukan.')));
    }

    final exitSecondsLeft =
        _exitOtpIntervalSeconds -
        (_now.millisecondsSinceEpoch ~/ 1000 % _exitOtpIntervalSeconds);
    final alarmSecondsLeft =
        _alarmOtpIntervalSeconds -
        (_now.millisecondsSinceEpoch ~/ 1000 % _alarmOtpIntervalSeconds);
    final exitOtp = _generateOtp(
      session.exitSecret,
      intervalSeconds: _exitOtpIntervalSeconds,
    );
    final alarmOtp = _generateOtp(
      session.alarmSecret,
      intervalSeconds: _alarmOtpIntervalSeconds,
    );
    final qrPayload = isSuperAdmin ? _buildQrPayload(session) : null;
    final displayedExamUrl = isSuperAdmin
        ? session.examUrl
        : _maskExamUrl(session.examUrl);

    return Scaffold(
      appBar: AppBar(title: Text(session.name)),
      body: BlueGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionCard(
              title: 'Informasi Sesi',
              subtitle: 'OTP digenerate secara lokal dari secret sesi.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${session.status.label}'),
                  const SizedBox(height: 8),
                  Text('URL: $displayedExamUrl'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OtpCard(
              title: 'Exit OTP',
              code: exitOtp,
              secondsLeft: exitSecondsLeft,
              description:
                  'Dipakai pengawas untuk mengakhiri ujian siswa secara normal. Masa berlaku 60 menit.',
            ),
            const SizedBox(height: 16),
            _OtpCard(
              title: 'Alarm OTP',
              code: alarmOtp,
              secondsLeft: alarmSecondsLeft,
              description:
                  'Dipakai admin/pengawas untuk reset layar cheat warning. Berubah tiap 60 detik, valid hingga ~11 menit.',
            ),
            if (isSuperAdmin) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'QR Sesi',
                subtitle:
                    'Super admin menghasilkan QR dari payload JSON yang berisi URL, session id, exit secret, dan alarm secret.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(
                            data: qrPayload!,
                            size: 240,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isDownloading
                          ? null
                          : () => _downloadQrCode(
                              session: session,
                              payload: qrPayload,
                            ),
                      icon: const Icon(Icons.download),
                      label: Text(
                        _isDownloading ? 'Mengunduh...' : 'Download QR',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Payload QR',
                subtitle:
                    'Format JSON ini sesuai rule integrasi dengan ExamBro.',
                child: SelectableText(qrPayload),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Aksi Super Admin',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: session.status == SessionStatus.active
                          ? null
                          : () => _updateStatus(context, SessionStatus.active),
                      child: const Text('Aktifkan'),
                    ),
                    FilledButton.tonal(
                      onPressed: session.status == SessionStatus.ended
                          ? null
                          : () => _updateStatus(context, SessionStatus.ended),
                      child: const Text('Akhiri'),
                    ),
                    
                    FilledButton.tonal(
                      onPressed: () => _showEditSessionDialog(context, session),
                      child: const Text('Edit Sesi'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _showDeleteConfirmation(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      ),
                      child: const Text('Hapus Sesi'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _generateOtp(String secret, {required int intervalSeconds}) {
    return OTP.generateTOTPCodeString(
      secret,
      _now.millisecondsSinceEpoch,
      interval: intervalSeconds,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  String _buildQrPayload(ExamSession session) {
    final durationMinutes = session.endsAt
        .difference(session.startsAt)
        .inMinutes;

    return const JsonEncoder.withIndent('  ').convert({
      'url': session.examUrl,
      'session_id': session.id,
      'duration_minutes': durationMinutes,
      'ends_at': session.endsAt.toUtc().toIso8601String(),
      'exit_otp_interval_seconds': _exitOtpIntervalSeconds,
      'alarm_otp_interval_seconds': _alarmOtpIntervalSeconds,
      'exit_secret': session.exitSecret,
      'alarm_secret': session.alarmSecret,
    });
  }

  Future<void> _downloadQrCode({
    required ExamSession session,
    required String payload,
  }) async {
    setState(() => _isDownloading = true);

    try {
      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );
      
      // 1. Generate QR Image
      final image = await painter.toImage(2048);
      
      // 2. Create a Canvas with a white background
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 2048, 2048), paint);
      
      // 3. Draw the QR code on top
      canvas.drawImage(image, Offset.zero, Paint());
      
      // 4. Convert to PNG bytes
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(2048, 2048);
      final byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null) {
        throw StateError('QR image data is empty.');
      }

      final fileName =
          'qr-${session.id}-'
          '${DateTime.now().millisecondsSinceEpoch}.png';

      // Save to Gallery
      final result = await SaverGallery.saveImage(
        Uint8List.fromList(bytes),
        fileName: fileName,
        androidRelativePath: 'Pictures/Proctor',
        skipIfExists: false,
      );

      if (!mounted) {
        return;
      }

      if (result.isSuccess) {
        // Try to construct expected public path for OpenFile
        // /storage/emulated/0/Pictures/Proctor/...
        final publicPath = '/storage/emulated/0/Pictures/Proctor/$fileName';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('QR berhasil disimpan ke galeri'),
            action: SnackBarAction(
              label: 'Lihat',
              onPressed: () => OpenFile.open(publicPath),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan QR: '
              '${result.errorMessage ?? 'Unknown error'}',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal mengunduh QR.')));
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _showEditSessionDialog(
    BuildContext context,
    ExamSession session,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EditSessionDialog(session: session),
    );
  }

  Future<void> _updateStatus(BuildContext context, SessionStatus status) async {
    await context.read<SessionController>().updateStatus(
      sessionId: widget.sessionId,
      status: status,
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Sesi?'),
          content: const Text(
            'Sesi ini akan dihapus secara permanen. '
            'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final router = GoRouter.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      await context.read<SessionController>().deleteSession(widget.sessionId);

      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/');
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Sesi berhasil dihapus.')),
      );
    }
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.title,
    required this.code,
    required this.secondsLeft,
    required this.description,
  });

  final String title;
  final String code;
  final int secondsLeft;
  final String description;

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft <= 30
        ? secondsLeft / 30
        : (secondsLeft / 3600).clamp(0.0, 1.0);
    final digits = code.split('').join(' ');

    return SectionCard(
      title: title,
      subtitle: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(digits, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(_buildRemainingLabel(secondsLeft)),
        ],
      ),
    );
  }

  String _buildRemainingLabel(int totalSeconds) {
    if (totalSeconds >= 60) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;

      if (hours > 0) {
        return 'Berlaku $hours jam ${minutes.toString().padLeft(2, '0')} menit lagi';
      }

      return 'Berlaku $minutes menit lagi';
    }

    return 'Berlaku $totalSeconds detik lagi';
  }
}

class _EditSessionDialog extends StatefulWidget {
  const _EditSessionDialog({required this.session});

  final ExamSession session;

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _durationController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _urlController = TextEditingController(text: widget.session.examUrl);
    final durationMinutes = widget.session.endsAt
        .difference(widget.session.startsAt)
        .inMinutes;
    _durationController = TextEditingController(text: '$durationMinutes');
    _selectedDate = widget.session.startsAt;
    _selectedTime = TimeOfDay.fromDateTime(widget.session.startsAt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Sesi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama sesi'),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL ujian'),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Durasi ujian (menit)',
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedDate == null
                    ? 'Pilih Tanggal'
                    : 'Tanggal: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
              ),
              trailing: const Icon(Icons.calendar_today),
              enabled: !_isSubmitting,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(
                    const Duration(days: 1),
                  ),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && mounted) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedTime == null
                    ? 'Pilih Jam'
                    : 'Jam: ${_selectedTime!.format(context)}',
              ),
              trailing: const Icon(Icons.access_time),
              enabled: !_isSubmitting,
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (time != null && mounted) {
                  setState(() => _selectedTime = time);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan URL wajib diisi.')),
      );
      return;
    }

    final durationMinutes = int.tryParse(_durationController.text);
    if (durationMinutes == null || durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durasi ujian harus berupa angka positif.'),
        ),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal dan waktu ujian.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final startsAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final session = await context.read<SessionController>().updateSession(
        sessionId: widget.session.id,
        name: _nameController.text,
        examUrl: _urlController.text,
        durationMinutes: durationMinutes,
        startsAt: startsAt,
      );

      if (mounted) {
        navigator.pop();
        if (session != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Sesi berhasil diupdate.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Gagal mengupdate sesi.')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}
