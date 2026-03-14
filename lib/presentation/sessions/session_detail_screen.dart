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
  static const int _exitOtpIntervalSeconds = 3600;
  static const int _alarmOtpIntervalSeconds = 30;

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
                  'Dipakai admin/pengawas untuk reset layar cheat warning. Masa berlaku 30 detik.',
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
