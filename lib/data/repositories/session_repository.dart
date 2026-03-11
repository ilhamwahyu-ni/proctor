import 'dart:math';

import 'package:proctor/data/models/exam_session.dart';

/// In-memory session repository used until Firebase integration is added.
class SessionRepository {
  /// Creates the repository with seeded sessions.
  SessionRepository() : _sessions = _seedSessions();

  final List<ExamSession> _sessions;

  static List<ExamSession> _seedSessions() {
    final now = DateTime.now();

    return [
      ExamSession(
        id: 'uas-fisika-12a',
        name: 'UAS Fisika 12A',
        examUrl: 'https://exam.school.id/uas-fisika-12a',
        exitSecret: 'JBSWY3DPEHPK3PXP',
        alarmSecret: 'KRSXG5CTMVRXEZLU',
        createdBy: 'u-super-admin',
        createdAt: now.subtract(const Duration(days: 2)),
        startsAt: now.subtract(const Duration(minutes: 15)),
        endsAt: now.add(const Duration(hours: 1, minutes: 45)),
        status: SessionStatus.active,
      ),
      ExamSession(
        id: 'uas-matematika-11b',
        name: 'UAS Matematika 11B',
        examUrl: 'https://exam.school.id/uas-matematika-11b',
        exitSecret: 'MFRGGZDFMZTWQ2LK',
        alarmSecret: 'ONSWG4TFOQWWI33M',
        createdBy: 'u-super-admin',
        createdAt: now.subtract(const Duration(days: 1)),
        startsAt: now.add(const Duration(hours: 3)),
        endsAt: now.add(const Duration(hours: 5)),
        status: SessionStatus.scheduled,
      ),
    ];
  }

  /// Returns all sessions sorted by start time.
  List<ExamSession> getAllSessions() {
    final sessions = [..._sessions]
      ..sort((left, right) {
        return left.startsAt.compareTo(right.startsAt);
      });

    return sessions;
  }

  /// Returns only active sessions for proctor views.
  List<ExamSession> getActiveSessions() {
    return getAllSessions()
        .where((session) => session.status == SessionStatus.active)
        .toList();
  }

  /// Returns a session by id if available.
  ExamSession? findById(String sessionId) {
    return _sessions.where((session) => session.id == sessionId).firstOrNull;
  }

  /// Creates a new scheduled session with generated secrets.
  ExamSession createSession({
    required String name,
    required String examUrl,
    required String createdBy,
    required int durationMinutes,
  }) {
    final now = DateTime.now();
    final startsAt = now.add(const Duration(minutes: 30));
    final session = ExamSession(
      id: _slugify(name),
      name: name.trim(),
      examUrl: examUrl.trim(),
      exitSecret: _generateSecret(),
      alarmSecret: _generateSecret(),
      createdBy: createdBy,
      createdAt: now,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: durationMinutes)),
      status: SessionStatus.scheduled,
    );

    _sessions.add(session);
    return session;
  }

  /// Updates the status of an existing session.
  ExamSession updateStatus({
    required String sessionId,
    required SessionStatus status,
  }) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    final updatedSession = _sessions[index].copyWith(status: status);

    _sessions[index] = updatedSession;
    return updatedSession;
  }

  String _slugify(String input) {
    final slug = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return '$slug-${_sessions.length + 1}';
  }

  String _generateSecret() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();

    return List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
