import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:provider/provider.dart';
import 'package:proctor/data/models/exam_session.dart';
import 'package:proctor/data/models/user_role.dart';
import 'package:proctor/presentation/common/blue_gradient_background.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';
import 'package:proctor/state/session_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  late final Timer _timer;
  DateTime _now = DateTime.now();
  bool _isDownloading = false;

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

    final secondsLeft = 30 - (_now.second % 30);
    final exitOtp = _generateOtp(session.exitSecret);
    final alarmOtp = _generateOtp(session.alarmSecret);
    final qrPayload = _buildQrPayload(session);

    return Scaffold(
      appBar: AppBar(title: Text(session.name)),
      body: BlueGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionCard(
              title: 'Informasi Sesi',
              subtitle:
                  'OTP tetap digenerate lokal dari secret yang ada di memori scaffold.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${session.status.label}'),
                  const SizedBox(height: 8),
                  Text('URL: ${session.examUrl}'),
                  const SizedBox(height: 8),
                  Text('Mulai: ${session.startsAt}'),
                  const SizedBox(height: 8),
                  Text('Selesai: ${session.endsAt}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OtpCard(
              title: 'Exit OTP',
              code: exitOtp,
              secondsLeft: secondsLeft,
              description:
                  'Dipakai pengawas untuk mengakhiri ujian siswa secara normal.',
            ),
            const SizedBox(height: 16),
            _OtpCard(
              title: 'Alarm OTP',
              code: alarmOtp,
              secondsLeft: secondsLeft,
              description:
                  'Dipakai admin/pengawas untuk reset layar cheat warning.',
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(
                            data: qrPayload,
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
                              context: context,
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
                      onPressed: session.status == SessionStatus.scheduled
                          ? null
                          : () =>
                                _updateStatus(context, SessionStatus.scheduled),
                      child: const Text('Jadwalkan Ulang'),
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

  String _generateOtp(String secret) {
    return OTP.generateTOTPCodeString(
      secret,
      _now.millisecondsSinceEpoch,
      interval: 30,
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
      'exit_secret': session.exitSecret,
      'alarm_secret': session.alarmSecret,
    });
  }

  Future<void> _downloadQrCode({
    required BuildContext context,
    required ExamSession session,
    required String payload,
  }) async {
    setState(() => _isDownloading = true);

    try {
      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
      );
      final imageData = await painter.toImageData(2048);
      final bytes = imageData?.buffer.asUint8List();

      if (bytes == null) {
        throw StateError('QR image data is empty.');
      }

      final savedPath = await FileSaver.instance.saveFile(
        name: 'qr-${session.id}',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR berhasil diunduh: $savedPath')),
      );
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

  Future<void> _updateStatus(BuildContext context, SessionStatus status) async {
    await context.read<SessionController>().updateStatus(
      sessionId: widget.sessionId,
      status: status,
    );
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
    final progress = secondsLeft / 30;
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
          Text('Berlaku $secondsLeft detik lagi'),
        ],
      ),
    );
  }
}
