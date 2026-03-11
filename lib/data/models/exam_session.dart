/// Status values available for an exam session.
enum SessionStatus { scheduled, active, ended }

/// Readable labels for [SessionStatus].
extension SessionStatusX on SessionStatus {
  /// Returns a human-readable label.
  String get label => switch (this) {
    SessionStatus.scheduled => 'Scheduled',
    SessionStatus.active => 'Active',
    SessionStatus.ended => 'Ended',
  };
}

/// Session model used by super admin and proctor flows.
class ExamSession {
  /// Creates an immutable exam session.
  const ExamSession({
    required this.id,
    required this.name,
    required this.examUrl,
    required this.exitSecret,
    required this.alarmSecret,
    required this.createdBy,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  /// Session identifier.
  final String id;

  /// Session name shown in the UI.
  final String name;

  /// Destination exam URL embedded in the QR payload.
  final String examUrl;

  /// TOTP secret for normal exit verification.
  final String exitSecret;

  /// TOTP secret for cheat-warning reset verification.
  final String alarmSecret;

  /// Creator user id.
  final String createdBy;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Planned start time.
  final DateTime startsAt;

  /// Planned end time.
  final DateTime endsAt;

  /// Current lifecycle status.
  final SessionStatus status;

  /// Returns a copy with updated fields.
  ExamSession copyWith({
    String? id,
    String? name,
    String? examUrl,
    String? exitSecret,
    String? alarmSecret,
    String? createdBy,
    DateTime? createdAt,
    DateTime? startsAt,
    DateTime? endsAt,
    SessionStatus? status,
  }) {
    return ExamSession(
      id: id ?? this.id,
      name: name ?? this.name,
      examUrl: examUrl ?? this.examUrl,
      exitSecret: exitSecret ?? this.exitSecret,
      alarmSecret: alarmSecret ?? this.alarmSecret,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
    );
  }
}
