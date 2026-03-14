import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Firestore string representation.
  String get firestoreValue => name;

  /// Parses a Firestore status string back to [SessionStatus].
  static SessionStatus fromString(String value) => switch (value) {
    'active' => SessionStatus.active,
    'ended' => SessionStatus.ended,
    _ => SessionStatus.scheduled,
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

  /// Creates an [ExamSession] from a Firestore document snapshot.
  factory ExamSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ExamSession(
      id: doc.id,
      name: data['name'] as String,
      examUrl: data['examUrl'] as String,
      exitSecret: data['exitSecret'] as String,
      alarmSecret: data['alarmSecret'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startsAt: (data['startsAt'] as Timestamp).toDate(),
      endsAt: (data['endsAt'] as Timestamp).toDate(),
      status: SessionStatusX.fromString(data['status'] as String),
    );
  }

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

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'examUrl': examUrl,
      'exitSecret': exitSecret,
      'alarmSecret': alarmSecret,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': status.firestoreValue,
    };
  }

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
